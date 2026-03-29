---
description: "Reply to PR review comments via the GitHub API. Replies appear in both GitHub and Reviewable. Atomic skill used by /bty after addressing review feedback."
---

# Reply to Review Comments

Post replies to PR review comment threads via the GitHub API. Replies posted this way appear in both GitHub and Reviewable.

## Usage

For each comment thread that was addressed, compose a reply and post it:

```bash
~/.claude/skills/reply-comments/scripts/reply_comment.sh <COMMENT_ID> "<BODY>"
```

- `COMMENT_ID` — the `thread_id` from `/fetch-pr-comments` output
- `BODY` — the reply text

The script auto-detects the PR number from the current branch and the repo from `gh`.

## Writing Good Replies

- **Code changes:** Briefly state what was changed. Example: "Done — renamed `process_data` to `validate_input` and split the function."
- **Refactors:** Explain the approach. Example: "Refactored this into two functions for clarity. PTAL."
- **Deferred work:** Note the TODO. Example: "Added a TODO for this — too risky to change mid-stack. Will address in a follow-up PR."
- **Disagreements:** Explain the reasoning. Be respectful and concise.

Keep replies short. The code diff speaks for itself.

## Batch Replies

After `/bty` addresses multiple threads, reply to each one. For each thread in the `/fetch-pr-comments` output that was acted on, call the script with the appropriate `thread_id` and a reply summarizing the action taken.
