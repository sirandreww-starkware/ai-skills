---
description: "Find all open PRs that need attention and fix them. Handles unresponded reviews, CI failures, and multi-commit PRs. Use when the user says 'bty all', 'fix all PRs', 'address all reviews', 'fix everything', or wants to handle all outstanding PR issues."
---

# BTY All — Fix All PRs Needing Attention

Discover and fix PRs one at a time. After fixing each PR, re-run discovery to verify it no longer needs attention before moving on.

## Loop

Repeat the following steps until `/attention-prs` reports no PRs needing attention.

### Step 1: Discover Next PR

Request a single PR from `/attention-prs`:

```bash
~/.claude/skills/attention-prs/scripts/find_prs.sh 1
```

**No PRs found:** All done. Go to the Final Report.

Present the flagged PR and its reasons to the user. Ask for confirmation before proceeding.

### Step 2: Fix the PR

Check out the branch:

```bash
git checkout <BRANCH_NAME>
```

Dispatch based on the reason(s) it was flagged:

- **CI failing** -> run `/fix-ci`. Follow all steps in that skill.
- **Unresponded review comments** -> run `/bty`. Follow all steps in that skill.
- **Multiple commits** -> run `/squash`. Follow all steps in that skill.

If the PR has multiple reasons, fix them in this order: CI first, then reviews, then squash.

`/bty` submits on its own. For other dispatches (`/fix-ci`, `/squash`), run `/submit` after fixing.

### Step 3: Re-verify

Run `/attention-prs` again for the same PR to confirm it is no longer flagged:

```bash
~/.claude/skills/attention-prs/scripts/find_prs.sh 1
```

- **PR is gone from results:** It was fixed. Loop back to Step 1 for the next PR.
- **Same PR reappears (no new reviewer activity):** Something in the fix or skill pipeline didn't resolve the issue. Stop the loop, report the situation to the user, and suggest which skill may need a change (e.g., `/fix-ci` didn't actually fix the failing check, `/squash` left multiple commits, `/bty` replied but didn't address the comment). Do not retry the same PR blindly.

## Final Report

Provide a summary:

- List of PRs fixed and the action taken on each.
- Any PRs that were skipped or could not be fixed.
- Confirmation that all fixes were submitted.
