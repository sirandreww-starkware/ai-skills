---
description: "Fetch PR review comments, plan fixes with user, validate, and restack with Graphite"
---

# Fix PR Review Comments

Fetch code review comments for the current branch, plan fixes with the user, apply changes, and ensure the stack remains valid throughout the Graphite restacking process.

## Stack Awareness

This PR may be part of a Graphite stack. Before applying fixes, check child PRs in the stack (`gt ls`) — a reviewer's suggestion may already be addressed in a later PR. In that case, reply explaining where it's handled rather than duplicating the change. Conversely, avoid making changes that conflict with work already done up-stack.

## Step 1: Fetch & Filter Comments

Run `/fetch-pr-comments` to get actionable review threads. Follow all steps in that skill:

1. Run the script to fetch threads where the reviewer is waiting for a response.
2. Read the referenced code to understand current state.
3. Second-pass filter: check if issues were already addressed in code.
4. Present the active threads.

**No Comments:** If no actionable comments remain, inform the user and stop.

## Step 2: Plan with User ("Ask before you do")

**Do not apply fixes yet.** Present the active comments to the user and ask for specific direction on each:

1.  **Refactor (Preferred):** Is the reviewer confused? (See *Refactoring Strategy* below).
2.  **Accept Suggestion:** Apply the requested change directly?
3.  **Defer:** Is the fix too complex or risky? (See *Deferring Work* below).
4.  **Reply Only:** Respond with text without changing code?

**Wait for user confirmation before proceeding.**

## Step 3: Apply Fixes

Apply the changes based on the agreed plan.

* **Refactoring Strategy (Answer with Code):** If a reviewer asks a question or expresses confusion, **do not just explain it in a reply.** Refactor the code to eliminate the confusion (rename variables, restructure logic, split functions). Code comments are a fallback; self-documenting code is the goal.
* **Deferring Work:** If a fix is too large or creates massive conflicts up the stack, add a `TODO(AndrewL): ...` in the code to address it in a future PR.
* **Standard Fixes:** Read the relevant file and apply the edit.

## Step 4: Validate

Run `/validate` on the affected crate(s):

```bash
~/.claude/skills/validate/scripts/validate.sh -p <CRATE>
```

* **If Validation Fails:** Fix the errors and re-run validation until it passes. The `/validate` output includes fix suggestions for each failure type.
* **If Validation Passes:** Proceed to Step 5.

## Step 5: Amend & Restack

Run `/amend-restack` to commit the changes and handle any restack conflicts. Follow all steps in that skill.

## Step 6: Post-Amend Validation

Re-run `/validate` on the affected crate(s) to confirm the amend and restack didn't break anything:

```bash
~/.claude/skills/validate/scripts/validate.sh -p <CRATE>
```

If validation fails, fix the errors, re-validate, and re-amend (repeat Steps 5-6 until clean).

## Step 7: Submit

Run `/submit` to push the stack to the remote. The updated code must be visible before notifying reviewers.

## Step 8: Reply to Reviewers

Invoke `/reply-comments` using the Skill tool. It will present a reply table and stop the run so the user can post replies via Reviewable.

## Step 9: Final Report

Provide a summary:

* List of comments addressed and the action taken (Refactored/Fixed/Deferred).
* Confirmation that validation passed.
* Status of the Graphite stack.
