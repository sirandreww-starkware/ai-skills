---
name: polish
description: "Iterative review-fix-validate cycle that runs /review, /shahak-review, /security-review, and /codestyle-review, fixes all findings, and /validates until the PR is clean. Use when the user says 'polish', 'polish this PR', 'make this perfect', 'review and fix everything', or wants multiple rounds of review+fix."
argument-hint: "[max-rounds]"
---

# Polish

Run iterative review-fix-validate cycles on the current PR until no findings remain or the max
rounds are reached. Each round runs three review types, fixes all findings, and validates.

Default: 5 rounds. Pass a number as argument to override (e.g., `/polish 3`).

**CRITICAL:** Each round must end with `/validate` passing. Never leave the PR in a broken state
between rounds. If a fix introduces a new failure, fix it before moving to the next round.

## Step 0: Identify Crates

Identify which crate(s) were changed in this PR:

```bash
git diff HEAD^ --name-only | grep "^crates/" | sed 's|crates/\([^/]*\)/.*|\1|' | sort -u
```

Build the `-p` flags for validate (e.g., `-p crate_a -p crate_b`). Store these for reuse across
rounds.

## Round Loop (repeat up to max-rounds)

### Step 1: Review (run all four in parallel)

Run these four reviews **in parallel** to gather all findings before making changes:

1. **`/review`** — General code review: correctness, conventions, performance, test coverage.
2. **`/shahak-review`** — Shahak's specific preferences: naming, API design, documentation,
   testing patterns, code organization.
3. **`/security-review`** — Security-focused: input validation, auth, crypto, injection, data
   exposure. Only high-confidence findings.
4. **`/codestyle-review`** — Rust Coding Conventions: file/directory layout, error handling,
   async patterns, type safety, documentation, casting, imports, and more (51 rules total).

Collect ALL findings from all three reviews into a single ranked list:
- **High severity** (bugs, security issues, correctness errors) — fix first
- **Medium severity** (design issues, missing tests, naming) — fix second
- **Low severity** (comments, style, documentation) — fix last

### Step 2: Assess Findings

If **zero findings** across all three reviews, the PR is polished. Print the summary and stop.

If findings exist, proceed to Step 3.

### Step 3: Fix All Findings

Fix every finding from Step 1. For each fix:
- Make the code change
- If the fix touches a function, verify related tests still pass
- If the fix changes behavior, add or update a test

**Ordering matters:**
1. Fix correctness/security issues first (they may invalidate other findings)
2. Fix design/naming issues second
3. Fix documentation/comments last

After all fixes, run formatting:
```bash
unset CI && scripts/rust_fmt.sh
```

### Step 4: Amend and Validate

Amend the commit with all fixes:
```bash
gt m -a
```

Run the full validation suite:
```bash
~/.claude/skills/validate/scripts/validate.sh -p <crates...>
```

If validation **fails**:
- Read the error output
- Fix the issue (clippy, formatting, test failure, commitlint, etc.)
- Re-amend and re-validate
- Repeat until PASSED

If validation **passes**, proceed to the next round.

### Step 5: Report Round Results

After each round, print a brief summary:

```
Round N: X findings found, Y fixed, Z remaining. Validate: PASSED.
```

## Completion

After all rounds (or when zero findings are found), print the final summary:

```
## Polish Summary

| Round | Review Findings | Fixed | Validate |
|-------|----------------|-------|----------|
| 1     | 8              | 8     | PASSED   |
| 2     | 3              | 3     | PASSED   |
| 3     | 1              | 1     | PASSED   |
| 4     | 0              | -     | PASSED   |

PR is polished after 4 rounds. Total fixes: 12.
```

## Tips

- If the same finding keeps appearing across rounds, it may be a false positive or a fundamental
  design issue. Flag it for the user rather than cycling forever.
- Review findings from later rounds are often deeper / more subtle than early rounds. This is
  expected — each round peels off a layer.
- The adversarial/security review in later rounds should be more aggressive, looking for edge cases
  that only become visible after the obvious issues are fixed.
- If a finding is an intentional design decision (not a bug), document it with a code comment and
  move on. Don't cycle on accepted tradeoffs.
