---
name: insert-pr
description: "Create a new PR inserted into the Graphite stack above the current PR. Atomic skill used by other skills after code changes have been made and validated."
---

# Insert PR

Stage all changes, create a new branch/PR inserted into the Graphite stack between the current branch and its child, and handle any restack conflicts.

This skill assumes you have already made code changes and validated them with `/validate`. It does not submit — the caller or user should submit when ready.

## Step 1: Verify Preconditions

1. **Confirm there are changes to commit:**
   ```bash
   git status --porcelain
   ```
   If clean, warn the user and stop — nothing to insert.

2. **Check the stack position:**
   ```bash
   gt ls -s
   ```
   Note whether the current branch has children in the stack.

## Step 2: Create the Inserted Branch

The caller provides the commit message. Its **first line** must follow the repo's commitlint format (`scope: subject`), and it must include the three-section conversation-summary **body** (`## Goal`, `## Summary of changes`, `## Key decision points`) — draft it with `/commit-summary`. Pass the subject and body as two `-m` flags (the `-m` arg is array-typed; Graphite joins them with a blank line).

### If the current branch has children:

```bash
gt c -a --insert --no-interactive -m "scope: subject" -m "<body from /commit-summary>"
```

`--insert` creates a new branch between the current branch and its child. `--no-interactive` avoids prompts when there are multiple children (selects the first). `-a` stages all changes.

### If the current branch has NO children (top of stack):

```bash
gt c -a --no-interactive -m "scope: subject" -m "<body from /commit-summary>"
```

`--insert` is unnecessary at the top of the stack — a normal `gt c` creates the branch on top.

**IMPORTANT:** Always pass `--no-interactive` and `-a`.

## Step 3: Handle Restack Conflicts

After `gt c --insert`, Graphite restacks child branches on top of the new branch. This may produce conflicts.

Check for conflicts:
```bash
gt status
```

If conflicts exist, resolve them following the same procedure as `/amend-restack` Step 2:

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

## Step 4: Return to the Inserted Branch

After restack completes, you may be on a different branch. Navigate back to the newly inserted branch:

```bash
gt co <INSERTED_BRANCH_NAME>
```

Confirm with:
```bash
git branch --show-current
gt ls -s
```

## Escape Hatch

If a conflict or validation failure persists after 3 attempts on the same PR, stop and report the situation to the user rather than continuing to loop.
