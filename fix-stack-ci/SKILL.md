---
description: "Walk a Graphite PR stack upward from the current PR, running CI validation (formatting, clippy, tests) on each PR and fixing failures. Use when the user says 'fix stack', 'fix stack CI', 'walk the stack', 'validate stack', or wants to ensure PRs in a Graphite stack pass CI."
---

# Fix Stack CI

Validate the current PR and walk upward through the stack, fixing CI failures until every PR from here to the top is green.

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

**If the loop exits**, one of two things happened:
- **A validation step failed** -- proceed to Step 3.
- **The branch didn't change after `gt up`** (top of stack reached) -- every PR from here up is green. Done.

Determine which case by checking whether validation passed (re-run `/validate` alone if needed).

## Step 3: Fix the Failure

Run `/fix-ci` to fix the current PR's CI failure. Follow all steps in that skill.

## Step 4: Continue Walking Up

After `/fix-ci` completes, continue the validation walk from the current position. **MANDATORY:** Use the same `while_validate.sh` script as Step 2.

```bash
~/.claude/skills/fix-stack-ci/scripts/while_validate.sh <CRATE_FLAGS>
```

If another failure is found, go back to Step 3.
