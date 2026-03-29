---
description: "Rebase the current Graphite stack on the latest trunk (main). Use when the user says 'sync trunk', 'rebase on main', 'update from main', 'sync stack', or when CI fails due to stale trunk."
---

# Sync Trunk

Fetch the latest trunk and rebase the current stack on it, resolving any conflicts that arise.

## Step 1: Sync & Restack

Sync all branches with remote, fetch latest trunk, and restack:

```bash
gt sync
```

If the sync completes cleanly, skip to Step 3.

## Step 2: Resolve Conflicts

If `gt restack` pauses due to conflicts, run `/fix-stack-conflicts` to resolve them. Follow all steps in that skill.

## Step 3: Verify

Confirm the stack is clean:

```bash
gt ls -s
gt status
```

Report which branches were rebased and whether any conflicts were resolved.
