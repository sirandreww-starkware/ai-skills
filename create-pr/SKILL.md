---
name: create-pr
description: "Create a new PR from your working changes with Graphite: stage everything and commit with a `scope: subject` first line plus a three-section conversation-summary body. Use when the user says 'create PR', 'create a PR', 'make a PR', 'open a PR', or 'new PR'. Does not submit."
---

# Create PR

Stage all working changes and create a new Graphite branch/PR on top of the current branch,
with a commit message whose first line follows the repo's commitlint format and whose body is
the three-section conversation summary required for sequencer PRs.

This skill **creates the commit only** — it does not submit. Run `/validate` and then `/submit`
(or `gt s`) when ready. For inserting a PR *between* an existing branch and its child, use
`/insert-pr` instead.

## Step 1: Verify Preconditions

1. **Confirm there are changes to commit:**
   ```bash
   git status --porcelain
   ```
   If clean, warn the user and stop — nothing to create a PR from.

2. **Check the stack position:**
   ```bash
   gt ls -s
   ```
   `gt c` creates the new branch on top of the current branch. If the user wants the PR based
   off trunk, have them `gt co main` (or the trunk branch) first.

## Step 2: Draft the Commit Message

The message has two parts.

### First line — `scope: subject`

Must pass commitlint: `scope: subject`, where `scope` is one (or several comma-separated) of the
repo's allowed scopes, the whole header is ≤100 chars, and the subject is lowercase, imperative
mood, describing *what* changed — not *why*. No co-author trailer.

### Body — three-section conversation summary

Draft the body with `/commit-summary` — it produces the three sections (`## Goal`,
`## Summary of changes`, `## Key decision points`) from this Claude session. Keep its output
verbatim for the next step.

## Step 3: Create the Commit

The `-m` flag on `gt c` is array-typed, so pass the subject and the `/commit-summary` body as
two separate `-m` flags (Graphite joins them with a blank line):

```bash
gt c -a --no-interactive -m "scope: subject" -m "<body from /commit-summary>"
```

`-a` stages all changes; `--no-interactive` avoids prompts. Always pass both.

## Step 4: Stop — Do Not Submit

Confirm the commit:
```bash
git log -1 --format='%s%n%n%b'
git branch --show-current
```

Report the new branch to the user and tell them to run `/validate` and then `/submit` (or
`gt s`) when ready. Do not submit from this skill.
