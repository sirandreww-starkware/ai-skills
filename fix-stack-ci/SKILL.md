---
name: fix-stack-ci
description: Walk a Graphite PR stack upward from the current PR, running CI validation (formatting, clippy, tests) on each PR and fixing failures. Use when the user says "fix stack", "fix CI", "walk the stack", "validate stack", or wants to ensure PRs in a Graphite stack pass CI.
---

# Fix Stack

Validate the current PR and walk upward through the stack, fixing CI failures, amending, restacking, and continuing until every PR from here to the top is green.

The validation script is at `~/.claude/skills/fix-stack-ci/scripts/validate.sh`. It runs commitlint, formatting, clippy, and tests in sequence. It takes the same `-p` crate flags as cargo commands.

## Step 1: Identify Stack & Crates

1. **Show the stack:**
   ```bash
   gt ls -s
   ```
2. **Identify the crate(s) under test.** Find which crate(s) were changed. Identify the top branch name from `gt ls -s` output, then diff against it to find all changed files across the stack:
   ```bash
   git diff <STACK_TOP_BRANCH> --name-only
   ```
   Crate names come from `crates/<crate_name>/`. Collect all unique crate names across the stack if needed.

3. **Build the `-p` flags.** For a single crate: `-p apollo_propeller`. For multiple: `-p crate_a -p crate_b`.

## Step 2: Walk Up & Validate

**MANDATORY:** Run the validation walk as a SINGLE command in ONE Bash tool call. Do NOT run fmt, clippy, and tests as separate commands. Do NOT run them one PR at a time manually. The script validates the current PR, moves up with `gt up`, and repeats until the top of the stack or the first failure.

```bash
~/.claude/skills/fix-stack-ci/scripts/while_validate.sh <CRATE_FLAGS>
```

**IMPORTANT:** Do NOT pipe the validation scripts through `2>&1 | tail -30`. The scripts manage their own output.

Replace `<CRATE_FLAGS>` with the appropriate `-p` arguments (e.g. `-p apollo_propeller` or `-p crate_a -p crate_b`).

**If the loop exits**, one of two things happened:
- **A validation step failed** -- proceed to Step 3.
- **The branch didn't change after `gt up`** (top of stack reached) -- every PR from here up is green. Skip to Step 6.

Determine which case by checking whether validation passed (re-run the validation command alone if needed).

## Step 3: Fix the Failure

Read the error output to understand the failure:

- **Commitlint:** Fix the commit message to match the format `scope[,scope2,...]: subject`. Use `gt m` to amend the commit message.
- **Formatting:** Run `scripts/rust_fmt.sh` (without `--check`) to auto-fix.
- **Taplo:** Run `scripts/taplo.sh` to auto-fix TOML formatting.
- **Clippy:** Read the warnings/errors, fix the code.
- **Tests:** Read the failure output, fix the code.
- **Machete:** Remove unused dependencies from `Cargo.toml` files.

After fixing, re-run the validation to confirm:

```bash
~/.claude/skills/fix-stack-ci/scripts/validate.sh <CRATE_FLAGS>
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
      ~/.claude/skills/fix-stack-ci/scripts/validate.sh <CRATE_FLAGS>
      ```
   3. If validation fails, fix and re-validate.
   4. Stage and continue:
      ```bash
      gt add .
      gt cont
      ```
   5. Repeat until the entire stack is restacked.

   **Escape hatch:** If a conflict or validation failure persists after 3 attempts on the same PR, stop and report the situation to the user rather than continuing to loop.

## Step 5: Continue Walking Up

After the amend and restack complete, continue the validation walk from the current position. **MANDATORY:** Use the same `while_validate.sh` script as Step 2 — do NOT run commands individually per PR.

```bash
~/.claude/skills/fix-stack-ci/scripts/while_validate.sh <CRATE_FLAGS>
```

If another failure is found, go back to Step 3. Otherwise, if the top of the stack was reached, proceed to Step 6.

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
