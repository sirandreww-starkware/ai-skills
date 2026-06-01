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

## Step 1.5: Assess Change Impact

For each actionable comment, launch an `/assess-change` agent **in parallel** (one agent per comment, using the Agent tool with multiple concurrent calls). Each agent:

1. Takes the comment text, file path, and line number
2. Searches the codebase to trace the blast radius
3. Drafts a concrete fix plan (which files, which lines, what changes)
4. Returns: files affected, lines changed, crates involved, and a recommendation (amend vs insert-pr)

Wait for all assessments to complete before proceeding to Step 2.

## Step 2: Plan with User ("Ask before you do")

**Do not apply fixes yet.** Present each comment with its `/assess-change` results: files affected, lines changed, crates involved, and the recommendation. Then ask for direction on each:

1.  **Refactor (Preferred):** Is the reviewer confused? (See *Refactoring Strategy* below).
2.  **Accept Suggestion:** Apply the requested change directly?
3.  **Defer:** Is the fix too complex or risky? (See *Deferring Work* below).
4.  **Reply Only:** Respond with text without changing code?
5.  **Insert PR:** The fix requires a large change — file rename, restructure, or a small change that cascades across many files. Apply in a new PR inserted above the current one in the stack. (See *Phase 2* below).

Pre-select the `/assess-change` recommendation for each comment (amend → options 1-4, insert-pr → option 5), but the user can override any classification.

After the user confirms, group comments into two buckets:
- **Amend group:** Comments handled with Refactor, Accept, Defer, or Reply Only — these go into the current PR.
- **Insert PR group:** Comments flagged as Insert PR — each gets its own inserted PR.

**Wait for user confirmation before proceeding.**

## Steps 3–6: Two-Phase Execution

### Phase 1: Small Fixes (Amend into Current PR)

Skip this phase if there are no Amend group items.

**Step 3a: Apply Fixes**

Apply the Amend group changes based on the agreed plan.

* **Refactoring Strategy (Answer with Code):** If a reviewer asks a question or expresses confusion, **do not just explain it in a reply.** Refactor the code to eliminate the confusion (rename variables, restructure logic, split functions). Code comments are a fallback; self-documenting code is the goal.
* **Deferring Work:** If a fix is too large or creates massive conflicts up the stack, add a `TODO(AndrewL): ...` in the code to address it in a future PR.
* **Standard Fixes:** Read the relevant file and apply the edit.

Use the fix plans from `/assess-change` as a starting point — they list the specific files, lines, and changes needed.

**Step 4a: Validate**

Run `/validate` on the affected crate(s):

```bash
~/.claude/skills/validate/scripts/validate.sh -p <CRATE>
```

* **If Validation Fails:** Fix the errors and re-run validation until it passes.
* **If Validation Passes:** Proceed to Step 5a.

**Step 5a: Amend & Restack**

Run `/amend-restack` to commit the changes and handle any restack conflicts. Follow all steps in that skill.

**Step 6a: Post-Amend Validation**

Re-run `/validate` on the affected crate(s) to confirm the amend and restack didn't break anything:

```bash
~/.claude/skills/validate/scripts/validate.sh -p <CRATE>
```

If validation fails, fix the errors, re-validate, and re-amend (repeat Steps 5a-6a until clean).

### Phase 2: Large Fixes (Insert PRs)

Skip this phase if there are no Insert PR group items.

For each Insert PR comment, **one at a time** in the order the user confirmed:

**Step 3b: Apply the Fix**

Apply the changes for this single comment using the fix plan from `/assess-change`. You are on the current PR's branch (for the first insert) or the previously inserted branch (for subsequent inserts).

**Step 4b: Validate**

Run `/validate` on the affected crate(s):

```bash
~/.claude/skills/validate/scripts/validate.sh -p <CRATE>
```

Fix errors and re-run until passing.

**Step 5b: Insert PR**

Run `/insert-pr` with a commit message whose first line follows the repo's `scope: subject` commitlint format. Include the three-section conversation-summary body (`## Goal` / `## Summary of changes` / `## Key decision points`), drafted with `/commit-summary`, summarizing the review feedback being addressed and any decisions made while addressing it.

**Step 6b: Post-Insert Validation**

Re-run `/validate` to confirm the insert and any restack didn't break anything. If it fails, fix, re-validate, and re-insert (repeat Steps 5b-6b until clean).

**Step 6c: Stay on the Inserted Branch**

Remain on the newly inserted branch. The next Insert PR fix (if any) will build on top of this one. The resulting stack order is:

```
original-PR → insert-1 → insert-2 → ... → child-PR
```

After all Insert PR items are done, navigate back to the original PR's branch before proceeding to Step 7:

```bash
gt co <ORIGINAL_BRANCH>
```

## Step 7: Submit

Run `/submit` to push the stack to the remote. The updated code must be visible before notifying reviewers.

## Step 8: Reply to Reviewers

Invoke `/reply-comments` using the Skill tool. It will present a reply table and stop the run so the user can post replies via Reviewable.

For comments addressed in the current PR, reply as usual ("Done — renamed X to Y."). For comments addressed in an inserted PR, note that the fix is in a follow-up PR in the stack and include the branch name. Example: "Addressed in a follow-up PR above this one in the stack (`branch-name`). Renamed the file and updated all references."

## Step 9: Final Report

Provide a summary:

* List of comments addressed and the action taken (Refactored/Fixed/Deferred/Inserted PR).
* For inserted PRs: the branch name of each inserted PR.
* Confirmation that validation passed.
* Final stack structure (`gt ls -s`).
