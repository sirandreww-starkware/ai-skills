---
description: "Check if pending changes overlap with work already done in PRs above the current one in the stack. Use before amending to avoid squashing intentional splits."
---

# Check Upstack Overlap

Compare pending changes (staged + unstaged) against diffs in all PRs above the current one. Reports overlapping files so the caller can decide whether to proceed or revert.

This skill is read-only — it does not modify code.

## Step 1: Identify Pending Changes

Get the list of files with pending changes:

```bash
{ git diff --name-only; git diff --cached --name-only; } | sort -u
```

If no files have pending changes, report "no pending changes" and stop.

## Step 2: Identify Upstack Changes

Find the top branch of the stack from `gt ls -s` output. Then get all files changed in PRs above:

```bash
git diff HEAD..<TOP_BRANCH> --name-only | sort -u
```

If the current PR is the top of the stack (no branches above), report "no upstack PRs" and stop.

## Step 3: Find Overlapping Files

Intersect the two file lists. For each file that appears in both:

1. Show the pending change (what we're about to amend):
   ```bash
   git diff HEAD -- <FILE>
   ```

2. Show the upstack change (what's already done above):
   ```bash
   git diff HEAD..<TOP_BRANCH> -- <FILE>
   ```

## Step 4: Report

**No overlapping files:** Report "no overlap — safe to amend."

**Overlapping files found:** For each overlapping file, present:

- File path
- Summary of what the pending change does
- Summary of what the upstack change does
- Whether they touch the same lines or different parts of the file

Flag the overlap clearly. The caller should revert overlapping changes or confirm they are intentional before proceeding.
