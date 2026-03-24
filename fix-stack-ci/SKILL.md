---
name: fix-stack-ci
description: Walk a Graphite PR stack upward from the current PR, running CI validation (formatting, clippy, tests) on each PR and fixing failures. Use when the user says "fix stack", "fix CI", "walk the stack", "validate stack", or wants to ensure PRs in a Graphite stack pass CI.
---

# Fix Stack

Validate the current PR and walk upward through the stack, fixing CI failures, amending, restacking, and continuing until every PR from here to the top is green.

## Step 1: Identify Stack & Crates

1. **Show the stack:**
   ```bash
   gt ls -s
   ```
2. **Identify the crate(s) under test.** Ask the user which crate(s) are being worked on. If the user isn't sure, infer from changed files on the current branch:
   ```bash
   git diff HEAD^ --name-only
   ```
   Crate names come from `crates/<crate_name>/`. Collect all unique crate names across the stack if needed.

3. **Build the `-p` flags.** For a single crate: `-p apollo_propeller`. For multiple: `-p crate_a -p crate_b`.

## Step 2: Walk Up & Validate

**MANDATORY:** Run the validation as a SINGLE `while` loop in ONE Bash tool call. Do NOT run fmt, clippy, and tests as separate commands. Do NOT run them one PR at a time manually. Copy the loop below, substitute `<CRATE_FLAGS>`, and execute it in one shot. The loop stops at the first failure or when you reach the top of the stack.

**Important:** `gt up` returns exit code 0 even when already at the top of the stack. To detect the top, compare the branch name before and after `gt up`. If it didn't change, you've reached the top.

```bash
while scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>; do
  BEFORE=$(git branch --show-current)
  gt up
  AFTER=$(git branch --show-current)
  if [ "$BEFORE" = "$AFTER" ]; then break; fi
done 2>&1 | tail -30
```

**IMPORTANT:** The `2>&1 | tail -30` at the end is mandatory — it keeps output manageable by showing only the last 30 lines. This is critical for long-running validation across many PRs.

Replace `<CRATE_FLAGS>` with the appropriate `-p` arguments (e.g. `-p apollo_propeller` or `-p crate_a -p crate_b`).

**If the loop exits**, one of two things happened:
- **A validation step failed** -- proceed to Step 3.
- **The branch didn't change after `gt up`** (top of stack reached) -- every PR from here up is green. Skip to Step 6.

Determine which case by checking whether validation passed (re-run the validation command alone if needed).

## Step 3: Fix the Failure

Read the error output to understand the failure:

- **Formatting:** Run `scripts/rust_fmt.sh` (without `--check`) to auto-fix.
- **Clippy:** Read the warnings/errors, fix the code.
- **Tests:** Read the failure output, fix the code.

After fixing, re-run the full validation line to confirm:

```bash
scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>
```

Repeat until validation passes.

## Step 4: Amend & Restack

Once validation passes on the current PR:

1. **Amend the commit:**
   ```bash
   gt add -A && gt m
   ```
   **IMPORTANT:** Never pass `-m` to `gt m` — it changes the commit message. Use plain `gt m` to amend only the content.

   This amends the current PR's commit and triggers a restack of child PRs.

2. **Handle restack conflicts.** If `gt m` pauses due to conflicts:
   1. Resolve the merge conflicts in affected files. Incorporate both sides honestly -- do not drop TODOs or features.
   2. Validate the conflicting PR's crate(s):
      ```bash
      scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>
      ```
   3. If validation fails, fix and re-validate.
   4. Stage and continue:
      ```bash
      gt add .
      gt cont
      ```
   5. Repeat until the entire stack is restacked.

## Step 5: Continue Walking Up

After the amend and restack complete, continue the validation walk from the current position. **MANDATORY:** Use the same single `while` loop as Step 2 — do NOT run commands individually per PR.

```bash
while scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>; do
  BEFORE=$(git branch --show-current)
  gt up
  AFTER=$(git branch --show-current)
  if [ "$BEFORE" = "$AFTER" ]; then break; fi
done 2>&1 | tail -30
```

If another failure is found, go back to Step 3. Otherwise, if the branch didn't change after `gt up` (top of stack), proceed to Step 6.

## Step 6: Submit & Report

Once every PR from the starting point to the top passes validation:

1. **Submit:**
   ```bash
   gt s --no-interactive --no-edit
   ```

2. **Report to the user:**
   - Which PRs were already passing.
   - Which PRs had failures and what was fixed.
   - Confirmation that the full stack passes validation.
   - Graphite stack status.
