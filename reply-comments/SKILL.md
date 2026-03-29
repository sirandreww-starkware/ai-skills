---
description: "Reply to PR review comments via the GitHub API. Replies appear in both GitHub and Reviewable. Atomic skill used by /bty after addressing review feedback."
---

# Reply to Review Comments

Post replies to PR review comment threads via the GitHub API. Replies posted this way appear in both GitHub and Reviewable.

## Usage

Choose the type based on the `path` field from `/fetch-pr-comments` output:

- **`path` is not null** → `inline` (file-level review comment)
- **`path` is null** → `top-level` (Reviewable discussion) — **cannot be replied to via this script**

```bash
# Inline review comment
~/.claude/skills/reply-comments/scripts/reply_comment.sh inline <COMMENT_ID> "<BODY>"
```

- `COMMENT_ID` — the `thread_id` from `/fetch-pr-comments` output
- `BODY` — the reply text

The script auto-detects the PR number from the current branch and the repo from `gh`.

## Top-level Reviewable Discussions

Top-level discussions (`path == null`) are threaded server-side by Reviewable. Replies posted through the GitHub API won't thread correctly. For these, inform the user that they need to reply via Reviewable directly.

## Writing Good Replies

- **Code changes:** Briefly state what was changed. Example: "Done — renamed `process_data` to `validate_input` and split the function."
- **Refactors:** Explain the approach. Example: "Refactored this into two functions for clarity. PTAL."
- **Deferred work:** Note the TODO. Example: "Added a TODO for this — too risky to change mid-stack. Will address in a follow-up PR."
- **Disagreements:** Explain the reasoning. Be respectful and concise.

Keep replies short. The code diff speaks for itself.

## Batch Replies

After `/bty` addresses multiple threads, reply to each one. For inline threads, call the script. For top-level threads, inform the user to reply via Reviewable.
