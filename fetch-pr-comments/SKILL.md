---
description: "Fetch and filter actionable PR review comments for the current branch. Atomic skill used by other skills."
---

# Fetch PR Comments

Fetch review comments for the current branch's PR, filter for actionable threads, and present them for triage.

## Step 1: Run the Script

```bash
~/.claude/skills/fetch-pr-comments/scripts/fetch_comments.sh
```

The script outputs a JSON array of actionable review threads. Each thread has:
- `thread_id` — unique identifier
- `path` — file path (null for top-level review comments)
- `line` — line number (null for top-level review comments)
- `comments` — array of `{author, body, created_at}` in chronological order

A thread is "actionable" if the last comment is **not** by the PR author (i.e., the reviewer is waiting for a response).

## Step 2: Read Referenced Code

For each thread with a `path` and `line`, read the referenced file to understand the current state of the code.

Also examine the full PR diff to understand context:
```bash
git diff HEAD^
```

## Step 3: Second-Pass Filter

Review the actionable threads against the current code:
- **Already addressed:** If the code already reflects the requested change (e.g., a TODO was added, a rename was done), mark the thread as resolved — it just needs a reply.
- **Bot comments:** Include bot comments — they are actionable too.
- **Still active:** If the issue is still present in the code, keep the thread as needing action.

## Step 4: Present Results

If no actionable comments remain, inform the user and stop.

Otherwise, present each active thread with:
- The file path and line
- The full comment chain
- The current state of the referenced code
- Your assessment of what action is needed
