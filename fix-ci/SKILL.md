---
description: "Fix CI failures on the current PR. Validates, fixes errors, and amends the commit. Use when the user says 'fix CI', 'fix this PR', or when a single PR has failing checks."
---

# Fix CI

Validate the current PR, fix any CI failures, and amend the commit.

This skill does not submit. The caller or user should submit when ready.

## Step 1: Identify Crates

Identify which crate(s) were changed in this PR:

```bash
git diff HEAD^ --name-only
```

Crate names come from `crates/<crate_name>/`. Collect all unique crate names and build `-p` flags (e.g. `-p crate_a -p crate_b`).

## Step 2: Validate

Run `/validate` on the affected crate(s):

```bash
~/.claude/skills/validate/scripts/validate.sh <CRATE_FLAGS>
```

If validation passes, inform the user — nothing to fix. Stop here.

## Step 3: Fix the Failure

Read the error output. The `/validate` output includes the failing step and a suggested fix command. Follow those suggestions to resolve the failure.

After fixing, re-run `/validate`:

```bash
~/.claude/skills/validate/scripts/validate.sh <CRATE_FLAGS>
```

Repeat until validation passes.

## Step 4: Amend & Restack

Once validation passes, run `/amend-restack` to amend the commit and handle any restack conflicts. Follow all steps in that skill.
