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
1. **Commitlint** — commit message matches `scope: subject` format
2. **Single commit** — PR has exactly one commit
3. **PR title match** — commit message matches the remote PR title
4. **rustfmt** — Rust formatting
5. **taplo** — TOML formatting
6. **Cargo.lock** — lockfile consistency
7. **Clippy** — lint warnings (treated as errors)
8. **Nextest** — unit/integration tests
9. **Doc tests** — documentation tests
10. **Machete** — unused dependencies

## Output

- `PASSED` on success.
- On failure: the failing step name, last 20 lines of output, and a suggested fix command.

## Fixing Failures

- **Formatting:** Run `scripts/rust_fmt.sh` to auto-fix.
- **Taplo:** Run `scripts/taplo.sh` to auto-fix TOML formatting.
- **Clippy/tests:** Read the error output, fix the code, and re-run.
- **Commitlint:** Fix the commit message with `gt m -m "scope: subject"`.
- **Single commit:** Run `gt branch squash --no-edit` to squash into one commit.
- **PR title match:** Update the PR title or commit message so they match.
- **Machete:** Remove unused dependencies from `Cargo.toml`.

Re-run the script after fixing until it prints `PASSED`.
