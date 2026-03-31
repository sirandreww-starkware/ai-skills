---
description: "Prepare a Graphite PR stack for review. Syncs trunk, self-reviews each PR, addresses reviewer comments, and fixes CI across the stack. Use when the user says 'prepare stack', 'get stack ready', 'prepare for review', or wants to make a stack review-ready."
---

# Prepare Stack

Prepare the full Graphite PR stack for review by walking through five sequential phases. Each phase must complete cleanly before starting the next.

## Prerequisites

Verify the stack exists and is in a workable state:

```bash
gt ls -s
gt status
```

If a restack is in progress, resolve it first with `/fix-stack-conflicts` before proceeding.

Identify the crate(s) changed across the stack. Find the top branch name from `gt ls -s`, then:

```bash
git diff <STACK_TOP_BRANCH> --name-only
```

Crate names come from `crates/<crate_name>/`. Collect all unique crate names and build `-p` flags (e.g., `-p crate_a -p crate_b`). These flags are reused in validation steps throughout all phases.

---

## Phase 1: Sync Trunk

Ensure the stack is based on the latest trunk.

Run `/sync-trunk`. Follow all steps in that skill.

**Gate:** `gt ls -s` shows a clean stack with no restack in progress. If not, stop and report.

---

## Phase 2: Self-Review & Fix (Bottom to Top)

Review each PR against coding standards, fix findings, and amend.

### Step 2.1: Navigate to Bottom

```bash
gt bottom
```

### Step 2.2: Review Current PR

Run `/review` on the current PR number (get it with `gh pr view --json number -q .number`). This catches general code quality issues: correctness, conventions, performance, tests, security.

Then run `/shahak-review` on the current branch. This catches Shahak's specific review preferences: naming, API design, async patterns, documentation, testing patterns.

### Step 2.3: Fix Findings

If either review reports issues:

1. Fix each finding in the code.
2. Run `/validate` on the affected crate(s):
   ```bash
   ~/.claude/skills/validate/scripts/validate.sh <CRATE_FLAGS>
   ```
   Fix any validation failures and re-validate until passing.
3. Run `/amend-restack` to commit the fixes. Follow all steps in that skill.
4. **Re-review:** Run `/review` and `/shahak-review` again to verify all findings are addressed. If new violations appear, repeat this step. **Stop after 3 iterations maximum per PR** -- if violations persist, report them to the user and continue to the next PR.

If both reviews report no issues, skip to Step 2.4.

### Step 2.4: Move Up

```bash
BEFORE=$(git branch --show-current)
gt up
AFTER=$(git branch --show-current)
```

If `BEFORE` equals `AFTER`, the top of the stack has been reached. Proceed to Step 2.5.

Otherwise, go back to Step 2.2 for the next PR.

### Step 2.5: Submit the Stack

After all PRs have been reviewed and fixed, run `/submit` to push the stack to the remote. The updated code must be visible before addressing reviewer comments in Phase 3.

---

## Phase 3: Address Reviewer Comments (Bottom to Top)

Walk the stack and address outstanding review comments on each PR.

### Step 3.1: Navigate to Bottom

```bash
gt bottom
```

### Step 3.2: Check for Comments

Check for actionable review threads on the current PR:

```bash
~/.claude/skills/fetch-pr-comments/scripts/fetch_comments.sh
```

**No actionable comments:** Skip to Step 3.3.

**Actionable comments found:** Run `/bty`. Follow all steps in that skill. `/bty` validates, amend-restacks, submits, and invokes `/reply-comments` which **stops the run** so the user can post replies via Reviewable. When the user resumes, continue from Step 3.3.

### Step 3.3: Move Up

```bash
BEFORE=$(git branch --show-current)
gt up
AFTER=$(git branch --show-current)
```

If `BEFORE` equals `AFTER`, the top of the stack has been reached. Proceed to Phase 4.

Otherwise, go back to Step 3.2 for the next PR.

---

## Phase 4: Fix CI Across the Stack

Ensure every PR in the stack passes CI validation.

### Step 4.1: Navigate to Bottom

```bash
gt bottom
```

### Step 4.2: Walk & Validate

Run `/fix-stack-ci`. Follow all steps in that skill. It walks the stack upward, validates each PR, and fixes failures.

### Step 4.3: Submit

After all PRs pass CI, run `/submit` to push the final state to the remote.

---

## Phase 5: Final Verification

Confirm the stack is ready for review:

```bash
gt bottom
gt ls -s
gt status
```

Report to the user:

- Which PRs were reviewed and how many findings were fixed (Phase 2).
- Which PRs had reviewer comments addressed (Phase 3).
- Which PRs had CI failures fixed (Phase 4).
- Confirmation that the full stack is green and submitted.
