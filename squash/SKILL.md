---
description: "Squash multiple commits in the current PR into a single commit. Use when the user says 'squash', 'squash commits', 'fix multiple commits', or when attention-prs flags a PR with more than one commit."
---

# Squash Commits

Squash all commits in the current PR branch into a single commit, preserving the commit message of the first commit.

## Step 1: Verify State

1. **Check you're on a PR branch:**
   ```bash
   git branch --show-current
   gt ls -s
   ```

2. **Count commits in this PR:**
   ```bash
   gt log short
   ```
   If there is only 1 commit, inform the user and stop — nothing to squash.

3. **Check for uncommitted changes:**
   ```bash
   git status --porcelain
   ```
   If there are uncommitted changes, warn the user and stop.

## Step 2: Squash

Use Graphite's fold command to squash all commits in the current branch into one:

```bash
gt fold --keep bottom
```

This squashes all commits in the branch, keeping the bottom (earliest) commit's message.

## Step 3: Verify

Confirm the squash succeeded:

```bash
gt log short
```

There should now be exactly 1 commit. Report the result to the user.
