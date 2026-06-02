---
description: "Resolve merge conflicts in a Graphite PR stack after amending a mid-stack PR or rebasing on an updated trunk. Walks through each conflicting PR, resolves conflicts, validates with CI checks, and continues the restack. Use when the user says \"fix conflicts\", \"resolve conflicts\", \"restack\", \"gt restack\", \"continue restack\", or when a Graphite rebase/restack has paused due to conflicts."
---

# Fix Stack Conflicts

Resolve conflicts in a Graphite PR stack and get it back to a clean state.

This skill does not submit. The caller or user should submit when ready.

## Step 1: Kick Off the Restack

1. **Check current state:**
   ```bash
   gt ls -s
   gt status
   ```
   `gt ls -s` shows the current stack. `gt status` shows whether a restack is already in progress.

2. **Start the restack** (only if one is not already in progress):
   ```bash
   gt restack
   ```
   If `gt status` already shows a paused restack with conflicts, skip this and proceed directly to conflict resolution.

   If `gt restack` completes cleanly with no conflicts, skip to Step 6 — there is nothing to resolve.

3. **Identify the crate(s) being worked on.** Ask the user, or infer from changed files:
   ```bash
   git diff --name-only HEAD
   ```
   Crate names come from `crates/<crate_name>/`. Collect all unique crate names and build `-p` flags (e.g. `-p crate_a -p crate_b`).

4. **See the conflicts:**
   ```bash
   git diff --name-only --diff-filter=U
   ```

## Step 2: Resolve Conflicts

For each conflicting file:

1. Read the file and find conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
2. **Incorporate both sides honestly.** Do not drop TODOs, features, or logic from either side. When in doubt, keep both changes and reconcile.
3. Remove all conflict markers.

### Resolution Principles

- **Prefer the intent of both sides.** If one side adds a feature and the other refactors, keep the feature on top of the refactored code.
- **Never silently drop changes.** If a conflict is genuinely contradictory, ask the user.
- **Watch for subtle conflicts:** imports, `mod` declarations, `Cargo.toml` dependency lists -- these often have conflicts that auto-merge misses.

## Step 3: Validate

After resolving all conflicts in the current PR, run `/validate` with `--skip-commit-check`:

```bash
~/.claude/skills/validate/scripts/validate.sh --skip-commit-check <CRATE_FLAGS>
```

**IMPORTANT:** Always use `--skip-commit-check` during restack resolution. The commit state is temporary (rebase in progress), so the commitlint, single-commit, commit-body, and PR title checks will fail spuriously. These checks run normally after the restack completes.

The `/validate` output includes the failing step and a suggested fix command. Fix any failures and re-validate until it passes. Only proceed when validation passes.

## Step 4: Stage & Continue

Once validation passes:

```bash
gt add .
gt cont
```

This continues the restack to the next branch in the stack.

## Step 5: Repeat

If the next branch also has conflicts, go back to Step 2. Continue this loop until `gt cont` completes the full restack with no more conflicts.

## Step 6: Final Verification

After the restack completes:

```bash
gt status
```

Report to the user which branches had conflicts and how they were resolved.
