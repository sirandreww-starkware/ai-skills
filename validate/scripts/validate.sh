#!/bin/bash
set -euo pipefail
# Validate a PR: commitlint, formatting, clippy, tests, unused deps.
# Usage: validate.sh [-p crate_a] [--skip-commit-check]
#   --skip-commit-check: Skip commitlint, single-commit, and PR title checks.
#                        Use during restack conflict resolution when commit state is temporary.
# Output: "PASSED" on success, "Failed: <step>\nTry: <fix>" on failure.
# Must be run from the project root (scripts/ paths are relative).

SKIP_COMMIT_CHECK=false
CRATE_FLAGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-commit-check) SKIP_COMMIT_CHECK=true; shift ;;
    *) CRATE_FLAGS+=("$1"); shift ;;
  esac
done
# Re-set positional params to crate flags for downstream commands.
set -- "${CRATE_FLAGS[@]+"${CRATE_FLAGS[@]}"}"

run() {
  local name="$1" fix="$2"
  shift 2
  if ! output=$("$@" 2>&1); then
    echo ""
    echo "Failed: $name"
    echo "$output" | tail -20
    echo ""
    echo "Try: $fix"
    exit 1
  fi
}

if [ "$SKIP_COMMIT_CHECK" = false ]; then
  run "commitlint"  "fix commit message to match 'scope: subject' format" \
    bash -c 'git log -1 --format=%s | npx commitlint --verbose'

  # Check exactly one commit in this PR
  parent_branch=$(gt branch info 2>/dev/null | grep 'Parent:' | sed 's/Parent: //' || true)
  if [ -n "$parent_branch" ]; then
    commit_count=$(git rev-list --count "$parent_branch"..HEAD)
    if [ "$commit_count" -ne 1 ]; then
      if git merge-base --is-ancestor "$parent_branch" HEAD 2>/dev/null; then
        run "single commit" "squash to one commit: gt branch squash --no-edit" false
      else
        run "single commit" "restack to incorporate parent changes: gt restack" false
      fi
    fi

    run "named todos" "fix unnamed TODOs above to use format // TODO(name): description" \
      bash -c "sequencer_venv/bin/python scripts/named_todos.py --commit_id '$parent_branch'"
  fi

  # Check commit message matches remote PR title (skip if no PR exists)
  pr_title=$(gh pr view --json title --jq .title 2>/dev/null || true)
  if [ -n "$pr_title" ]; then
    commit_msg=$(git log -1 --format=%s)
    pr_number=$(gh pr view --json number --jq .number)
    run "pr title match" "run: gh api repos/{owner}/{repo}/pulls/$pr_number -f title=\"$commit_msg\" --method PATCH (or if the commit message is wrong: gt m -m \"$pr_title\")" \
      test "$commit_msg" = "$pr_title"
  fi
fi

run "rustfmt"     "scripts/rust_fmt.sh" \
  scripts/rust_fmt.sh --check

run "taplo"       "scripts/taplo.sh" \
  scripts/taplo.sh

run "cargo lock"  "cargo update to regenerate Cargo.lock" \
  bash -c 'cargo metadata --locked --format-version=1 > /dev/null'

run "clippy"      "fix the clippy warnings above" \
  cargo clippy "$@" --all-targets --all-features -- -D warnings

run "nextest"     "fix the failing tests above" \
  cargo nextest run "$@" --all-features

run "doc tests"   "fix the failing doc tests above" \
  cargo test "$@" --all-features --doc

run "rustdoc"     "fix the broken intra-doc links / rustdoc warnings above" \
  env "RUSTDOCFLAGS=-D warnings" cargo doc "$@" --no-deps --document-private-items

run "machete"     "remove unused dependencies from Cargo.toml" \
  cargo machete

echo "PASSED"
