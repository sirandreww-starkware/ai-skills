---
description: "Reply to PR review comments. Presents proposed replies as JSON with Reviewable links for the user to post manually. Stops the run so the user has time to post. Atomic skill used by /bty after addressing review feedback."
---

# Reply to Review Comments

Present proposed replies to PR review comment threads as JSON for the user to post via Reviewable. **This skill stops the run after presenting the JSON** so the user has time to open each link and post the replies.

## Steps

1. Get `OWNER/REPO` and `PR_NUMBER`:
   ```bash
   OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
   PR_NUMBER=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')
   ```

2. For each addressed comment thread, build a row using the `thread_id` from `/fetch-pr-comments` output.

3. Present the table, then **stop and wait for the user** before continuing any parent skill (e.g., `/bty`).

## Output Format

Output a JSON array. Each element has the thread summary, the reply text, and the Reviewable link.

```json
[
  {
    "thread": "Rename this variable",
    "reply": "Done — renamed to `validate_input`.",
    "link": "https://reviewable.io/reviews/org/repo/42#-123456"
  },
  {
    "thread": "Split this function",
    "reply": "Refactored into two functions. PTAL.",
    "link": "https://reviewable.io/reviews/org/repo/42#-789012"
  }
]
```

The Reviewable link format is:

```
https://reviewable.io/reviews/<OWNER>/<REPO>/<PR_NUMBER>#-<COMMENT_ID>
```

## Writing Good Replies

- **Code changes:** Briefly state what was changed. Example: "Done — renamed `process_data` to `validate_input` and split the function."
- **Refactors:** Explain the approach. Example: "Refactored into two functions for clarity. PTAL."
- **Deferred work:** Note the TODO. Example: "Added a TODO for this — too risky to change mid-stack. Will address in a follow-up PR."
- **Disagreements:** Explain the reasoning. Be respectful and concise.

Keep replies short. The code diff speaks for itself.

## Stopping Behavior

After presenting the JSON, **stop the run**. Do not continue to the next step of the parent skill. The user will resume when they are done posting replies.
