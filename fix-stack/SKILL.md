---
name: fix-stack
description: Walk a Graphite PR stack from bottom to top, running CI validation (formatting, clippy, tests) on each PR and fixing failures. Use when the user says "fix stack", "fix CI", "walk the stack", "validate stack", or wants to ensure all PRs in a Graphite stack pass CI.
---

# Fix Stack

Walk a Graphite PR stack from bottom to top, validate each PR, fix CI failures, amend, restack, and continue upward until the entire stack is green.

## Step 1: Identify Stack & Crates

1. **Show the stack:**
   ```bash
   gt ls
   ```
2. **Identify the crate(s) under test.** Ask the user which crate(s) are being worked on. If the user isn't sure, infer from the stack by inspecting changed files:
   ```bash
   gt bottom
   git diff HEAD^ --name-only
   ```
   Crate names come from `crates/<crate_name>/`. Collect all unique crate names across the stack if needed.

3. **Build the `-p` flags.** For a single crate: `-p apollo_propeller`. For multiple: `-p crate_a -p crate_b`.

## Step 2: Go to Bottom of Stack

```bash
gt bottom
```

## Step 3: Walk Up & Validate

Run a loop that validates each PR and walks up the stack. The loop stops at the first failure:

```bash
while cfmt -- --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS> && gt up; do :; done
```

Replace `<CRATE_FLAGS>` with the appropriate `-p` arguments (e.g. `-p apollo_propeller` or `-p crate_a -p crate_b`).

**If the loop exits**, one of two things happened:
- **A validation step failed** -- proceed to Step 4.
- **`gt up` failed because you're at the top** -- the whole stack is green. Skip to Step 7.

Determine which case by checking `gt up` output or re-running the validation command alone.

## Step 4: Fix the Failure

Read the error output to understand the failure:

- **Formatting:** Run `cfmt` (without `--check`) to auto-fix.
- **Clippy:** Read the warnings/errors, fix the code.
- **Tests:** Read the failure output, fix the code.

After fixing, re-run the full validation line to confirm:

```bash
cfmt -- --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>
```

Repeat until validation passes.

## Step 5: Amend & Restack

Once validation passes on the current PR:

1. **Amend the commit:**
   ```bash
   gt add -A && gt m
   ```
   This amends the current PR's commit and triggers a restack of child PRs.

2. **Handle restack conflicts.** If `gt m` pauses due to conflicts:
   1. Resolve the merge conflicts in affected files. Incorporate both sides honestly -- do not drop TODOs or features.
   2. Validate the conflicting PR's crate(s):
      ```bash
      cfmt -- --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>
      ```
   3. If validation fails, fix and re-validate.
   4. Stage and continue:
      ```bash
      gt add .
      gt cont
      ```
   5. Repeat until the entire stack is restacked.

## Step 6: Continue Walking Up

After the amend and restack complete, continue the validation walk from the current position:

```bash
while cfmt -- --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS> && gt up; do :; done
```

If another failure is found, go back to Step 4. Otherwise, if you've reached the top, proceed to Step 7.

## Step 7: Submit & Report

Once the entire stack passes validation:

1. **Submit:**
   ```bash
   gt s --no-interactive --no-edit
   ```

2. **Report to the user:**
   - Which PRs were already passing.
   - Which PRs had failures and what was fixed.
   - Confirmation that the full stack passes validation.
   - Graphite stack status.
