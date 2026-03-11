---
description: "Fetch PR review comments, plan fixes with user, validate, and restack with Graphite"
---

# Fix PR Review Comments

You are tasked with fetching code review comments for the current branch, planning fixes with the user, applying changes, and ensuring the stack remains valid throughout the Graphite restacking process.

## Step 1: Context & PR Identification

1.  **Identify the current branch:**
    ```bash
    git branch --show-current
    ```
2.  **Find the open PR:**
    ```bash
    gh pr list --head <branch_name> --json number,title,url
    ```
3.  **Identify Repo Owner/Name:**
    ```bash
    gh repo view --json nameWithOwner --jq .nameWithOwner
    ```

## Step 2: Fetch & Filter Comments

### Step 2.1: Fetch comments

Fetch review data to determine what requires action.

1.  **Fetch Top-Level Reviews** (raw JSON, no `--jq` — jq quoting breaks in non-interactive bash):
    ```bash
    gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
    ```
2.  **Fetch Inline Comments:**
    ```bash
    gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
    ```
    Parse the JSON output yourself to extract the relevant fields (id, author, path, line, body, in_reply_to_id, created_at, state).

### Step 2.2: Read code

First examine what the entire PR does:
```bash
git diff HEAD^
```

Then understand what changes have been done but not commited:
```bash
git diff
```

Then understand the lines that were referenced in the previous step.

### Step 2.3: Filter comments

**Filtering Rules:**
* **No Comments:** If the API returns no comments, inform the user and stop.
* **Resolved Discussions:** Group comments by thread (`in_reply_to_id`). If the **last reply is from the PR Author**, assume the discussion is resolved or pending the reviewer. **Skip these** unless they contain explicit, unaddressed TODOs.
* **Active Discussions:** Focus on threads where the last reply is **not** from the PR author.
* **Look at the code:** Refer to the code to see if the comments were adressed (a TODO was added or the issue is still there)
* **Adress Bot Comments** Bot comments are important too, don't forget to take them into account.

## Step 3: Plan with User ("Ask before you do")

**Do not apply fixes yet.** Present the active comments to the user and ask for specific direction on each:

1.  **Refactor (Preferred):** Is the reviewer confused? (See *Refactoring Strategy* below).
2.  **Accept Suggestion:** Apply the requested change directly?
3.  **Defer:** Is the fix too complex or risky? (See *Deferring Work* below).
4.  **Reply Only:** Respond with text without changing code?

**Wait for user confirmation before proceeding.**

## Step 4: Apply Fixes

Apply the changes based on the agreed plan.

* **Refactoring Strategy (Answer with Code):** If a reviewer asks a question or expresses confusion, **do not just explain it in a reply.** Refactor the code to eliminate the confusion (rename variables, restructure logic, split functions). Code comments are a fallback; self-documenting code is the goal.
* **Deferring Work:** If a fix is too large or creates massive conflicts up the stack, add a `TODO(AndrewL): ...` in the code to address it in a future PR.
* **Standard Fixes:** Read the relevant file and apply the edit.

## Step 5: Validate (Pre-Restack)

**Before** running any Graphite commands, you must validate the current state of the code to ensure the fix is correct.

Run the validation suite for the specific crate:
```bash
scripts/rust_fmt.sh --check && cargo clippy -p <CRATE> --all-targets -- -D warnings && cargo nextest run -p <CRATE>
```

You can fix formatting issues by running `scripts/rust_fmt.sh`

* **If Validation Fails:** Fix the errors and re-run validation until it passes.
* **If Validation Passes:** Proceed to Step 6.

## Step 6: Graphite Restack & Conflict Resolution

Update the PR and the rest of the stack using Graphite.

1. **Modify the PR:**
```bash
gt add -A && gt m && gt status

```

*This submits the changes and triggers a restack of child PRs.*
2. **Handle Restack Conflicts:**
If `gt m` pauses due to conflicts (or during the rebase process):
1. **Resolve:** Fix the merge conflicts in the affected files (make sure to not lose TODOs or features, incorprate both changes as honestly as posible).
2. **Validate (Crucial):** Run the validation command **again** on the affected crate to ensure the conflict resolution didn't break logic.
```bash
scripts/rust_fmt.sh --check && cargo clippy -p <CRATE> --all-targets -- -D warnings && cargo nextest run -p <CRATE>
```

3. **Continue:** Only when validation passes, stage and continue:
```bash
gt add .
gt cont

```

*Repeat this loop until the entire stack is successfully restacked.*

## Step 7: Submit PR

Once the code is fixed, validated, and restacked, submit the PR to the remote repo:
```bash
gt s --no-interactive --no-edit
```

## Step 8: Final Report

Provide a summary:

* List of comments addressed and the action taken (Refactored/Fixed/Deferred).
* Confirmation that validation (`clippy` & `nextest`) passed.
* Status of the Graphite stack.
