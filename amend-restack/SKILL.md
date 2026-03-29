---
description: "Amend the current PR commit and handle Graphite restack conflicts. Atomic skill used by other skills after code changes have been made and validated."
---

# Amend & Restack

Stage all changes, amend the current PR's commit via Graphite, and handle any restack conflicts that arise in child PRs.

This skill assumes you have already made code changes and validated them with `/validate`. It does not submit — the caller or user should submit when ready.

## Step 1: Amend the Commit

```bash
gt m -a && gt status
```

**IMPORTANT:** Never pass `-m` to `gt m` — it changes the commit message. Use `gt m -a` to stage all changes and amend in one step.

This amends the current PR's commit and triggers a restack of child PRs.

## Step 2: Handle Restack Conflicts

If `gt m` pauses due to conflicts (check `gt status`):

1. **Find conflicting files:**
   ```bash
   git diff --name-only --diff-filter=U
   ```

2. **Resolve conflicts.** Read each conflicting file, find conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`), and incorporate both sides honestly:
   - Do not drop TODOs, features, or logic from either side.
   - If one side adds a feature and the other refactors, keep the feature on top of the refactored code.
   - Watch for subtle conflicts in imports, `mod` declarations, and `Cargo.toml` dependency lists.
   - If a conflict is genuinely contradictory, ask the user.

3. **Validate the resolved code.** Run `/validate` on the affected crate(s):
   ```bash
   ~/.claude/skills/validate/scripts/validate.sh <CRATE_FLAGS>
   ```
   Fix any failures and re-validate until it passes.

4. **Stage and continue the restack:**
   ```bash
   gt add .
   gt cont
   ```

5. **Repeat** steps 1-4 if the next branch in the stack also has conflicts.

## Escape Hatch

If a conflict or validation failure persists after 3 attempts on the same PR, stop and report the situation to the user rather than continuing to loop.
