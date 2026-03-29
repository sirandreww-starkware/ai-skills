---
description: "Fetch PR review comments, plan fixes with user, validate, and restack with Graphite"
---

# Fix PR Review Comments

Fetch code review comments for the current branch, plan fixes with the user, apply changes, and ensure the stack remains valid throughout the Graphite restacking process.

This skill does not submit. The caller or user should submit when ready.

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

## Step 5: Reply to Reviewers

Run `/reply-comments` to post replies to each addressed thread. For each comment that was acted on, reply with a short summary of what was done (e.g., "Refactored into two functions for clarity" or "Added a TODO — will address in follow-up").

## Step 6: Amend & Restack

Run `/amend-restack` to commit the changes and handle any restack conflicts. Follow all steps in that skill.

## Step 7: Final Report

Provide a summary:

* List of comments addressed and the action taken (Refactored/Fixed/Deferred).
* Confirmation that validation passed.
* Status of the Graphite stack.
