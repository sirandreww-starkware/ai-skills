---
description: "Run /bty on every PR in a Graphite stack from bottom to top, resolving conflicts and CI issues first. Use when the user says 'bty all', 'fix all PRs', 'address all reviews', 'bty stack', or wants to handle review comments across an entire stack."
---

# BTY All — Address Review Comments Across an Entire Stack

Address PR review comments on every PR in the current Graphite stack, from bottom to top. Ensures the stack is conflict-free and CI-clean before addressing reviews on each PR individually.

## Step 1: Survey the Stack

1. **Show the stack:**
   ```bash
   gt ls -s
   ```
   Note the full list of PRs from bottom to top. This is your work list.

2. **Navigate to the bottom:**
   ```bash
   gt bottom
   ```

3. **Identify the crate(s) under test.** Ask the user which crate(s) are being worked on. If the user isn't sure, infer from changed files across the stack:
   ```bash
   git diff HEAD^ --name-only
   ```
   Crate names come from `crates/<crate_name>/`. Collect all unique crate names and build `-p` flags.

## Step 2: Resolve Stack Conflicts

Run `/fix-stack-conflicts` to ensure the stack is conflict-free. Follow all steps in that skill.

After conflicts are resolved, navigate back to the bottom:
```bash
gt bottom
```

## Step 3: Validate the Entire Stack (CI)

Run `/fix-stack-ci` from the bottom of the stack to ensure every PR passes CI. Follow all steps in that skill.

After the full stack passes CI, navigate back to the bottom:
```bash
gt bottom
```

## Step 4: BTY Each PR (Bottom to Top)

Walk the stack from bottom to top, running `/bty` on each PR.

For each PR:

1. **Run `/bty`** (all steps). If a PR has no actionable review comments, skip it and move to the next.

2. **Move to the next PR:**
   ```bash
   BEFORE=$(git branch --show-current)
   gt up
   AFTER=$(git branch --show-current)
   ```
   If `$BEFORE` equals `$AFTER`, you've reached the top — proceed to Step 5.

3. **Repeat** from sub-step 1 for the next PR.

## Step 5: Final Submit & Report

Once all PRs have been addressed:

1. **Submit the entire stack** by running `/submit`. Follow all steps in that skill.

2. **Report to the user:**
   - List of PRs and the action taken on each (comments addressed, skipped, deferred).
   - Confirmation that the full stack passes validation.
   - Graphite stack status.
