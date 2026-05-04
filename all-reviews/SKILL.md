---
name: all-reviews
description: "Run all four review skills (/review, /shahak-review, /security-review, /codestyle-review) in parallel and return aggregated findings grouped by file. Atomic skill used by /polish and /prepare-pr; can also be invoked directly when the user wants one-shot multi-review coverage without the fix or submit steps. Use when the user says 'all reviews', 'run all reviews', 'review everything', 'multi-review'."
argument-hint: "[branch-or-file]"
---

# All Reviews

Run all four review skills in parallel and aggregate their findings into a single report. This skill does NOT fix anything — it only reviews.

## Step 1: Detect PR Number (best-effort)

`/review` works against a PR number when one exists. Try to detect it:

```bash
PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)
```

If found, pass it to `/review`. If not, `/review` will fall back to its default behavior (current branch / pending changes).

## Step 2: Invoke Reviews in Parallel

In a **single message**, invoke all four reviews as concurrent Skill calls:

1. `/review` — General code quality: correctness, conventions, performance, tests, security. Pass `$PR_NUMBER` if detected; otherwise no args.
2. `/shahak-review $ARGUMENTS` — Shahak's preferences: naming, API design, async patterns, documentation, testing patterns.
3. `/security-review $ARGUMENTS` — Focused security review of the pending changes.
4. `/codestyle-review $ARGUMENTS` — Rust Coding Conventions (51 rules: file layout, error handling, async patterns, type safety, documentation, casting, imports, etc.).

`$ARGUMENTS` defaults to the current branch / pending changes if the user passed nothing.

## Step 3: Aggregate Findings

Collect findings from all four reviews. Deduplicate by `(file, line, finding-substance)` — the same issue may be flagged by multiple reviewers (e.g., naming flagged by both `/review` and `/shahak-review`); keep the most informative variant and note the additional sources in a `(also flagged by: …)` suffix.

Group findings by file path (relative to the repo root). Sort by line number within each file.

## Output

```markdown
## All Reviews

### <file path>
- **L<line>** — `[<source>]` <finding>
  - Fix: <suggestion>
- **L<line>** — `[<source>]` <finding> (also flagged by: <other source>)
  - Fix: <suggestion>

### <next file path>
- ...

## Summary

| Source | Findings |
|--------|----------|
| /review | <count> |
| /shahak-review | <count> |
| /security-review | <count> |
| /codestyle-review | <count> |

**Total: N unique findings across M files.** (X duplicates collapsed.)
```

If zero findings overall:

```
All reviews: clean. No findings.
```

## Notes

- This is an atomic skill — composition only. It does not fix, validate, amend, or submit.
- Callers (`/polish`, `/prepare-pr`) layer their own fix/validate/submit logic on top of these findings.
- If a specific review fails (e.g., `/review` errors because no PR exists), report the failure inline but still aggregate findings from the reviews that did succeed.
