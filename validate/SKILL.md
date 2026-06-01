---
description: "Run CI validation (commitlint, formatting, clippy, tests, unused deps) on the current PR. Atomic skill used by other skills."
---

# Validate

Run the full CI validation suite on the current PR.

## Usage

```bash
~/.claude/skills/validate/scripts/validate.sh -p <CRATE> [-p <CRATE2> ...]
```

The script runs these checks in order, stopping at the first failure:
1. **Commitlint** — commit message **first line** matches `scope: subject` format
2. **Single commit** — PR has exactly one commit
3. **Commit body** — body carries the three-section conversation summary (`## Goal`, `## Summary of changes`, `## Key decision points`) — drafted by `/commit-summary`
4. **PR title match** — commit **first line** matches the remote PR title
5. **rustfmt** — Rust formatting
6. **taplo** — TOML formatting
7. **Cargo.lock** — lockfile consistency
8. **Clippy** — lint warnings (treated as errors)
9. **Nextest** — unit/integration tests
10. **Doc tests** — documentation tests
11. **Machete** — unused dependencies

## Output

- `PASSED` on success.
- On failure: the failing step name, last 20 lines of output, and a suggested fix command.

## Fixing Failures

- **Formatting:** Run `scripts/rust_fmt.sh` to auto-fix.
- **Taplo:** Run `scripts/taplo.sh` to auto-fix TOML formatting.
- **Clippy/tests:** Read the error output, fix the code, and re-run.
- **Commitlint:** Fix the commit's first line. Edit with `gt m` (opens the editor so the conversation-summary body is preserved), or pass subject and body as two flags: `gt m -m "scope: subject" -m "<body>"`. Do **not** run `gt m -m "scope: subject"` alone — that drops the body.
- **Single commit:** Run `gt branch squash --no-edit` to squash into one commit.
- **Commit body:** Add the missing `## Goal` / `## Summary of changes` / `## Key decision points` section to the commit body — use `/commit-summary` to draft it.
- **PR title match:** Update the PR title to match the first line, or fix the first line via `gt m` (preserving the body) so they match.
- **Machete:** Remove unused dependencies from `Cargo.toml`.

Re-run the script after fixing until it prints `PASSED`.
