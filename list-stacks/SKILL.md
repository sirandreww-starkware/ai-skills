---
description: "Identify separate Graphite PR stacks in the current repo"
---

# List Stacks

Identify all separate Graphite PR stacks by reading the branch tree from Graphite's internal metadata.

## Step 1: Run the script

```bash
~/.claude/skills/list-stacks/scripts/list_stacks.sh
```

## Step 2: Present results

Show the user which stacks exist, how many PRs each contains, and which stack they are currently on. If a stack has forks (branches splitting into sub-stacks), note the fork count.

## Step 3: Offer next steps

Ask the user if they want to:
- Navigate to a stack: `gt co <branch-name>`
- See full details of a stack: `gt ls` (after checking out a branch in that stack)
- Act on a stack (fix CI, address reviews, etc.)
