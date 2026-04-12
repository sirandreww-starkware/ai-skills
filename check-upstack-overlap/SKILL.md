---
description: "Check if pending changes overlap with work already done in PRs above the current one in the stack. Use before amending to avoid squashing intentional splits."
---

# Check Upstack Overlap

Compare the current PR's changed files against diffs in all PRs above. Reports overlapping files so the caller can decide whether a proposed fix is already handled up-stack.

This skill is read-only — it does not modify code.

## Step 1: Run the overlap script

```bash
~/.claude/skills/check-upstack-overlap/scripts/check_overlap.sh
```

This will:
1. Get the files changed in the current PR (`git diff HEAD^ --name-only`)
2. Find the top branch of the stack from `gt ls -s`
3. Show the upstack diff scoped to only those files (`git diff HEAD..<top> -- <files>`)

## Step 2: Analyze the output

**No overlap:** Report "no overlap — safe to proceed" and stop.

**Overlapping files found:** For each overlapping file, analyze:

- What the upstack change does to that file
- Whether a proposed fix for the current PR would conflict with or duplicate the upstack work
- Recommend: **skip** (already handled above), **proceed** (different concern), or **coordinate** (overlapping but not identical)

Flag findings clearly. The caller should skip fixes that duplicate upstack work.
