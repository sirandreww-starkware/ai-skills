---
name: fix-stack-conflicts
description: Resolve merge conflicts in a Graphite PR stack after amending a mid-stack PR or rebasing on an updated trunk. Walks through each conflicting PR, resolves conflicts, validates with CI checks, and continues the restack. Use when the user says "fix conflicts", "resolve conflicts", "restack", "gt restack", "continue restack", or when a Graphite rebase/restack has paused due to conflicts.
---

# Fix Stack Conflicts

Resolve conflicts in a Graphite PR stack and get it back to a clean state.

## Step 1: Assess the Situation

1. **Check current state:**
   ```bash
   gt ls -s
   gt status
   ```
   `gt ls -s` shows the current stack. `gt status` shows which branch has conflicts and the restack progress.

2. **Identify the crate(s) being worked on.** Ask the user, or infer from changed files:
   ```bash
   git diff --name-only HEAD
   ```
   Crate names come from `crates/<crate_name>/`.

3. **See the conflicts:**
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

After resolving all conflicts in the current PR, run the full validation suite:

```bash
~/.claude/skills/fix-stack-ci/scripts/validate.sh <CRATE_FLAGS>
```

- **Formatting issues:** Run `scripts/rust_fmt.sh` to auto-fix, then re-check.
- **Taplo:** Run `scripts/taplo.sh` to auto-fix TOML formatting.
- **Clippy/test failures:** Fix the code and re-validate.
- **Machete:** Remove unused dependencies from `Cargo.toml` files.
- **Only proceed when validation passes.**

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

**Check the stack is clean:**
```bash
gt status
```

## Step 7: Submit

```bash
gt s --no-interactive --no-edit
```

Report to the user which branches had conflicts and how they were resolved.
