---
name: commit-summary
description: "Draft the three-section conversation-summary body for a sequencer PR commit message (Goal / Summary of changes / Key decision points), from the current Claude session. Use when the user says 'write the commit summary', 'draft the PR description', 'write the commit body', or when a PR-authoring skill (/create-pr, /insert-pr, /bty) needs the body. Atomic skill."
---

# Commit Summary

Draft the conversation-summary **body** that sequencer PR commit messages must carry, from the
Claude session that produced the change. This skill produces only the body — the caller pairs it
with a `scope: subject` first line (see `/create-pr`, `/insert-pr`).

This requirement is Shahak's preference for sequencer PRs: reviewers (and future-Shahak) should
see not just the diff but the reasoning behind it — the *why* and the paths not taken, which are
otherwise lost when the chat ends. The diff shows the "what"; this body captures the "why". It is
a personal preference, not a repo-wide policy — don't push it on other contributors.

## The Body Format

Append a blank line after the subject, then these three sections, in this order, with the
headers **exactly** as shown (this is what `/validate` checks for):

```
## Goal
The problem being fixed or the thing being improved.

## Summary of changes
What was actually changed.

## Key decision points
For each non-trivial decision: what was decided, why, which alternatives
were considered, and why they were rejected.
```

## How to Draft It

1. **Goal** — state the problem this PR solves or the thing it improves. One or two sentences.
2. **Summary of changes** — describe what was actually changed (the *what*), grounded in the
   diff. Keep it factual; this complements, not repeats, the code.
3. **Key decision points** — walk back through *this conversation* and surface each non-trivial
   judgment call: what was decided, why, what alternatives were considered, and why they were
   rejected. This is the most valuable section — the rejected alternatives are the part that is
   otherwise lost.

Include all three headings even on small PRs. The *Key decision points* section may be brief, or
say "none" when there genuinely were no judgment calls — but keep the heading so `/validate`
passes.

## Output

Hand the drafted body back to the caller (or, if invoked directly, show it to the user) so it can
be passed as the body `-m` to `gt c` / `gt m`. Do not create or amend a commit from this skill —
that is the caller's job.
