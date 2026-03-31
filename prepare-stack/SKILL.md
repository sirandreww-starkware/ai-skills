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

If the stack has conflicts after sync, run `/fix-stack-conflicts`. Follow all steps in that skill.

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

## Step 4: Verify

```bash
gt bottom
gt ls -s
gt status
```

Report to the user:

- Summary of self-review findings fixed per PR.
- CI failures resolved per PR.
- Confirmation that the full stack is green and submitted.

### Comment Reply Guide

Throughout the stack walk, track every reviewer comment encountered on each PR. At the end, present a consolidated reply guide grouped by PR (branch name). For each comment show:

| PR | Reviewer | Comment (summarized) | Action Taken | Suggested Reply |
|----|----------|---------------------|--------------|-----------------|

- **Action Taken:** Refactored / Fixed / Deferred (with TODO) / Skipped (handled up-stack)
- **Suggested Reply:** A concise reply the user can post on Reviewable, explaining what was done and where to look in the updated diff.

This gives the user a single reference for any replies they haven't posted yet.
