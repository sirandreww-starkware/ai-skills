---
name: bty-all
description: "Run /bty on every PR in a Graphite stack from bottom to top, resolving conflicts and CI issues first. Use when the user says 'bty all', 'fix all PRs', 'address all reviews', 'bty stack', or wants to handle review comments across an entire stack."
---

# BTY All — Address Review Comments Across an Entire Stack

You are tasked with addressing PR review comments on every PR in the current Graphite stack, from bottom to top. This involves ensuring the stack is conflict-free and CI-clean before addressing reviews on each PR individually.

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
   Crate names come from `crates/<crate_name>/`. Collect all unique crate names.

4. **Build the `-p` flags.** For a single crate: `-p apollo_propeller`. For multiple: `-p crate_a -p crate_b`.

## Step 2: Resolve Stack Conflicts

Before doing any work, ensure the stack is conflict-free by running the `/fix-stack-conflicts` skill.

Follow all steps in `/fix-stack-conflicts` (assess, resolve, validate, stage & continue, repeat until clean).

After conflicts are resolved, navigate back to the bottom:
```bash
gt bottom
```

## Step 3: Validate the Entire Stack (CI)

Run the `/fix-stack-ci` skill from the bottom of the stack to ensure every PR passes CI.

Follow all steps in `/fix-stack-ci` (identify crates, walk up & validate, fix failures, amend & restack, continue walking). **Do not submit at the end of fix-stack-ci** — skip the submit step.

**Important:** The walk-up loop must detect the top of the stack by comparing branch names before and after `gt up`. If the branch didn't change, you've reached the top:

```bash
while scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>; do
  BEFORE=$(git branch --show-current)
  gt up
  AFTER=$(git branch --show-current)
  if [ "$BEFORE" = "$AFTER" ]; then break; fi
done
```

After the full stack passes CI, navigate back to the bottom:
```bash
gt bottom
```

## Step 4: BTY Each PR (Bottom to Top)

Now walk the stack from bottom to top, running `/bty` on each PR **without submitting after each one**.

For each PR:

1. **Run `/bty` steps 1-6** (Context & PR Identification, Fetch & Filter Comments, Plan with User, Apply Fixes, Validate, Graphite Restack & Conflict Resolution).
   - **Skip Step 7 (Submit)** — do not submit after each individual PR.
   - If a PR has no actionable review comments, skip it and move to the next.

2. **After applying fixes and validating**, ensure the restack from `gt m` completed cleanly. If there are conflicts in child PRs, resolve them following the conflict resolution process (resolve, validate, `gt add . && gt cont`).

3. **Move to the next PR:**
   ```bash
   BEFORE=$(git branch --show-current)
   gt up
   AFTER=$(git branch --show-current)
   ```
   If `$BEFORE` equals `$AFTER`, you've reached the top — proceed to Step 5.

4. **Repeat** from sub-step 1 for the next PR.

## Step 5: Final Submit & Report

Once all PRs have been addressed:

1. **Submit the entire stack:**
   ```bash
   gt s --no-interactive --no-edit
   ```

2. **Report to the user:**
   - List of PRs and the action taken on each (comments addressed, skipped, deferred).
   - Confirmation that the full stack passes validation.
   - Graphite stack status.
