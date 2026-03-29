---
description: "Find all open PRs that need attention and fix them. Handles unresponded reviews, CI failures, and multi-commit PRs. Use when the user says 'bty all', 'fix all PRs', 'address all reviews', 'fix everything', or wants to handle all outstanding PR issues."
---

# BTY All — Fix All PRs Needing Attention

Discover all open PRs that need attention and fix them by dispatching to the appropriate skill.

## Step 1: Discover PRs

Run `/attention-prs` to find PRs needing action:

```bash
~/.claude/skills/attention-prs/scripts/find_prs.sh
```

Present the results to the user, grouped by urgency:
- **CI failures** — these block merging
- **Unresponded review comments** — these block approval
- **Multiple commits** — these need squashing before merge

If no PRs need attention, inform the user and stop.

## Step 2: Confirm Scope

Ask the user which PRs to fix. Options:
- **All** — fix every flagged PR
- **Selective** — the user picks specific PRs or categories

**Wait for user confirmation before proceeding.**

## Step 3: Fix Each PR

For each PR to fix, check out the branch:

```bash
git checkout <BRANCH_NAME>
```

Then dispatch based on the reason(s) it was flagged:

- **CI failing** → run `/fix-ci`. Follow all steps in that skill.
- **Unresponded review comments** → run `/bty`. Follow all steps in that skill.
- **Multiple commits** → run `/squash`. Follow all steps in that skill.

If a PR has multiple reasons, fix them in this order: CI first, then reviews, then squash.

After fixing, run `/submit` to push the changes.

## Step 4: Report

Provide a summary:

- List of PRs and the action taken on each.
- Any PRs that were skipped or could not be fixed.
- Confirmation that fixes were submitted.
