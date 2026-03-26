#!/bin/bash
# Validate a PR: commitlint, formatting, clippy, tests, unused deps.
# Usage: validate.sh -p crate_a [-p crate_b ...]
# Output: "PASSED" on success, "Failed: <step>\nTry: <fix>" on failure.

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

run "commitlint"  "fix commit message to match 'scope: subject' format" \
  bash -c 'git log -1 --format=%s | commitlint --verbose'

run "rustfmt"     "scripts/rust_fmt.sh" \
  scripts/rust_fmt.sh --check

run "taplo"       "scripts/taplo.sh" \
  scripts/taplo.sh

run "cargo lock"  "cargo update to regenerate Cargo.lock" \
  cargo metadata --locked --format-version=1

run "clippy"      "fix the clippy warnings above" \
  cargo clippy "$@" --all-targets -- -D warnings

run "nextest"     "fix the failing tests above" \
  cargo nextest run "$@"

run "doc tests"   "fix the failing doc tests above" \
  cargo test "$@" --doc

run "machete"     "remove unused dependencies from Cargo.toml" \
  cargo machete

echo "PASSED"
