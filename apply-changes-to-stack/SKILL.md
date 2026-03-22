---
name: apply-changes-to-stack
description: Apply a list of code changes across a Graphite PR stack, walking bottom-to-top, validating each PR, amending with `gt m`, resolving restack conflicts, and submitting. Use when you have a set of fixes mapped to specific PRs in a stack (e.g., from a review) and need to apply them all.
---

# Apply Changes to Stack

Apply a pre-planned set of code changes across a Graphite PR stack. Walk from the bottom PR to the top, applying changes, validating, amending, and resolving restack conflicts along the way.

## Inputs

Before starting, you must have:

1. **A change list**: A mapping of branch names to the changes that need to be applied on that branch. Changes can span multiple PRs. A single change may also affect multiple PRs if it touches shared code that gets restacked.
2. **The crate(s) under modification**: Needed for validation commands.

## Step 1: Identify Stack & Navigate to Bottom

1. **Show the stack:**
   ```bash
   gt ls -s
   ```

2. **Navigate to the bottom-most PR that has changes:**
   ```bash
   gt co <bottom_branch_with_changes>
   ```

3. **Build the crate flags** for validation. For the `apollo_network_benchmark` crate: `-p apollo_network_benchmark`.

## Step 2: Apply Changes to Current PR

1. **Read the current branch name:**
   ```bash
   git branch --show-current
   ```

2. **Look up the change list** for this branch. If no changes are planned for this branch, skip to Step 5.

3. **Read the relevant files** before editing. Understand the current state of the code at this point in the stack (earlier PRs may not have certain code yet).

4. **Apply the edits.** Use the Edit tool for surgical changes. Be careful:
   - Code at this point in the stack may differ from the top-of-stack version you reviewed.
   - Only apply changes relevant to THIS PR's diff. Don't fix code that was introduced in a later PR.
   - If a change cannot be applied because the code doesn't exist yet at this stack level, defer it to the PR where the code is introduced.

## Step 3: Validate

Run the full validation suite:

```bash
scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>
```

- **Formatting issues:** Run `scripts/rust_fmt.sh` to auto-fix, then re-check.
- **Clippy/test failures:** Fix the code and re-validate.
- **Only proceed when validation passes.**

## Step 4: Amend & Restack

Once validation passes:

1. **Amend the commit:**
   ```bash
   gt add -A && gt m
   ```
   This amends the current PR's commit and triggers a restack of child PRs.

2. **Handle restack conflicts.** If `gt m` pauses due to conflicts:
   1. Check which files conflict:
      ```bash
      git diff --name-only --diff-filter=U
      ```
   2. Read each conflicting file and resolve conflicts. **Incorporate both sides honestly** -- do not drop TODOs, features, or logic from either side.
   3. Validate the conflicting PR's crate(s):
      ```bash
      scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS>
      ```
   4. If validation fails, fix and re-validate.
   5. Stage and continue:
      ```bash
      gt add .
      gt cont
      ```
   6. Repeat until the entire stack is restacked.

## Step 5: Move Up

Move to the next PR in the stack:

```bash
gt up
```

- If `gt up` succeeds, go back to **Step 2**.
- If `gt up` fails (you're at the top), proceed to **Step 6**.

## Step 6: Final Validation Walk (Optional)

If you want full confidence, walk the entire stack from bottom to top validating:

```bash
gt co <bottom_branch>
while scripts/rust_fmt.sh --check && cargo clippy -p <CRATE_FLAGS> --all-targets -- -D warnings && cargo nextest run -p <CRATE_FLAGS> && gt up; do :; done
```

## Step 7: Submit & Report

1. **Submit all changes:**
   ```bash
   gt s --no-interactive --no-edit
   ```

2. **Report to the user:**
   - Which PRs had changes applied.
   - Which PRs required conflict resolution and how conflicts were resolved.
   - Confirmation that validation passed across the stack.
   - Any deferred changes that couldn't be applied.
