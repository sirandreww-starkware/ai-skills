---
description: "Reply to PR review comments. Presents a table of proposed replies with Reviewable links for the user to post manually. Atomic skill used by /bty after addressing review feedback."
---

# Reply to Review Comments

Present proposed replies to PR review comment threads as a table for the user to post via Reviewable.

## Usage

For each comment thread that was addressed, build a table row with:

1. **Thread** — short description (e.g., the reviewer's ask)
2. **Reply** — the proposed response text
3. **Link** — Reviewable link to the thread

### Building the Reviewable Link

The link format is:

```
https://reviewable.io/reviews/<OWNER>/<REPO>/<PR_NUMBER>#-<COMMENT_ID>
```

Get `OWNER/REPO` from `gh repo view --json nameWithOwner --jq .nameWithOwner` and `PR_NUMBER` from the current branch. The `COMMENT_ID` is the `thread_id` from `/fetch-pr-comments` output.

### Output Format

Present the table to the user:

```
| # | Thread | Reply | Link |
|---|--------|-------|------|
| 1 | Rename this variable | Done — renamed to `validate_input`. | [reviewable](https://reviewable.io/reviews/org/repo/42#-123456) |
| 2 | Split this function  | Refactored into two functions. PTAL. | [reviewable](https://reviewable.io/reviews/org/repo/42#-789012) |
```

The user will open each link and post the reply themselves.

## Writing Good Replies

- **Code changes:** Briefly state what was changed. Example: "Done — renamed `process_data` to `validate_input` and split the function."
- **Refactors:** Explain the approach. Example: "Refactored into two functions for clarity. PTAL."
- **Deferred work:** Note the TODO. Example: "Added a TODO for this — too risky to change mid-stack. Will address in a follow-up PR."
- **Disagreements:** Explain the reasoning. Be respectful and concise.

Keep replies short. The code diff speaks for itself.
