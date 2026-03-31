---
description: "Fully prepare a single PR for review: self-review, address reviewer comments, and pass CI. Use when the user says 'prepare PR', 'prepare this PR', 'get this PR ready', or when called by /prepare-stack for each PR in a stack walk."
---

# Prepare PR

Fully prepare the current PR for review in a single pass: self-review against coding standards, address any outstanding reviewer comments, and ensure CI passes.

This skill submits after completing all steps so the remote is always up to date.

**CRITICAL: Do NOT fix issues that are already addressed in PRs above this one in the stack.** Reviews may flag things that a later PR intentionally handles. Fixing them here squashes the split and creates conflicts up-stack. When a review finding touches code that is modified in an upstack PR, skip that finding.

## Step 1: Identify Crates

Identify which crate(s) were changed in this PR:

```bash
git diff HEAD^ --name-only
```

Crate names come from `crates/<crate_name>/`. Collect all unique crate names and build `-p` flags (e.g., `-p crate_a -p crate_b`).

## Step 2: Self-Review

Run `/review` on the current PR number (get it with `gh pr view --json number -q .number`). This catches general code quality issues: correctness, conventions, performance, tests, security.

Then run `/shahak-review` on the current branch. This catches Shahak's specific review preferences: naming, API design, async patterns, documentation, testing patterns.

If both reviews report no issues, skip to Step 4.

## Step 3: Fix Review Findings

1. Fix each finding in the code.
2. **Check for upstack overlap:** Run `/check-upstack-overlap` to verify the fixes don't duplicate work in PRs above. If overlap is detected, revert the overlapping changes — those findings should be skipped since they're handled up-stack. Report the skipped findings to the user.
3. Run `/validate` on the affected crate(s):
   ```bash
   ~/.claude/skills/validate/scripts/validate.sh <CRATE_FLAGS>
   ```
   Fix any validation failures and re-validate until passing.
4. Run `/amend-restack` to commit the fixes. Follow all steps in that skill.
5. **Re-review:** Run `/review` and `/shahak-review` again to verify all findings are addressed. If new violations appear, repeat this step. **Stop after 3 iterations maximum** -- if violations persist, report them to the user and continue to Step 4.

## Step 4: Address Reviewer Comments

Check for actionable review threads on the current PR:

```bash
~/.claude/skills/fetch-pr-comments/scripts/fetch_comments.sh
```

**No actionable comments:** Skip to Step 5.

**Actionable comments found:** Run `/bty`. Follow all steps in that skill. `/bty` submits and invokes `/reply-comments` which **stops the run** so the user can post replies via Reviewable. When the user resumes, continue to Step 5.

## Step 5: Final CI Validation

Run `/validate` on the affected crate(s) one final time to catch any regressions introduced by earlier fixes:

```bash
~/.claude/skills/validate/scripts/validate.sh <CRATE_FLAGS>
```

If validation fails, fix the errors and re-validate. Once passing, run `/amend-restack` if any new changes were made. Follow all steps in that skill.

## Step 6: Submit

Run `/submit` to push the stack to the remote.
