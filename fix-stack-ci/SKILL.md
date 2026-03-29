---
description: Walk a Graphite PR stack upward from the current PR, running CI validation (formatting, clippy, tests) on each PR and fixing failures. Use when the user says "fix stack", "fix CI", "walk the stack", "validate stack", or wants to ensure PRs in a Graphite stack pass CI.
---

# Fix Stack CI

Validate the current PR and walk upward through the stack, fixing CI failures, amending, restacking, and continuing until every PR from here to the top is green.

This skill does not submit. The caller or user should submit when ready.

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
- **The branch didn't change after `gt up`** (top of stack reached) -- every PR from here up is green. Done.

Determine which case by checking whether validation passed (re-run `/validate` alone if needed).

## Step 3: Fix the Failure

Read the error output to understand the failure:

- **Commitlint:** Fix the commit message to match the format `scope[,scope2,...]: subject`. Use `gt m -m "new message"` to amend the commit message.
- **Formatting:** Run `scripts/rust_fmt.sh` (without `--check`) to auto-fix.
- **Taplo:** Run `scripts/taplo.sh` to auto-fix TOML formatting.
- **Clippy:** Read the warnings/errors, fix the code.
- **Tests:** Read the failure output, fix the code.
- **Machete:** Remove unused dependencies from `Cargo.toml` files.

After fixing, re-run `/validate` to confirm:

```bash
~/.claude/skills/validate/scripts/validate.sh <CRATE_FLAGS>
```

Repeat until validation passes.

## Step 4: Amend & Restack

Once validation passes, run `/amend-restack` to amend the commit and handle any restack conflicts. Follow all steps in `/amend-restack`.

## Step 5: Continue Walking Up

After the amend and restack complete, continue the validation walk from the current position. **MANDATORY:** Use the same `while_validate.sh` script as Step 2.

```bash
~/.claude/skills/fix-stack-ci/scripts/while_validate.sh <CRATE_FLAGS>
```

If another failure is found, go back to Step 3.
