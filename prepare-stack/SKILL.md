---
description: "Prepare a Graphite PR stack for review. Syncs trunk, then walks the stack bottom-to-top running /prepare-pr on each PR. Use when the user says 'prepare stack', 'get stack ready', 'prepare for review', or wants to make a stack review-ready."
---

# Prepare Stack

Sync the stack on latest trunk, then walk bottom-to-top preparing each PR for review.

## Step 1: Verify Stack

```bash
gt ls -s
gt status
```

If a restack is in progress, resolve it first with `/fix-stack-conflicts` before proceeding.

## Step 2: Sync Trunk

Run `/sync-trunk`. Follow all steps in that skill.

**Gate:** `gt ls -s` shows a clean stack with no restack in progress. If not, stop and report.

## Step 3: Walk Stack (Bottom to Top)

```bash
gt bottom
```

### For Each PR

Run `/prepare-pr` on the current PR. Follow all steps in that skill.

Then move up:

```bash
BEFORE=$(git branch --show-current)
gt up
AFTER=$(git branch --show-current)
```

If `BEFORE` equals `AFTER`, the top of the stack has been reached. Proceed to Step 4.

Otherwise, run `/prepare-pr` on the next PR.

## Step 4: Submit & Verify

Run `/submit` to push the final state of the full stack to the remote.

```bash
gt bottom
gt ls -s
gt status
```

Report to the user:

- Summary of findings fixed and comments addressed per PR.
- Confirmation that the full stack is green and submitted.
