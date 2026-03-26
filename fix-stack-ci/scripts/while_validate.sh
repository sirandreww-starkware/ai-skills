#!/bin/bash
set -euo pipefail
# Walk up a Graphite PR stack, running validate.sh on each PR.
# Usage: while_validate.sh -p crate_a [-p crate_b ...]
# Stops at first validation failure or when the top of the stack is reached.
# Prints the current branch before each validation run.
# Exit code: 0 if all PRs passed, 1 if a validation failure occurred.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while true; do
  echo "--- Validating: $(git branch --show-current) ---"
  if ! "$SCRIPT_DIR/validate.sh" "$@"; then
    exit 1
  fi
  BEFORE=$(git branch --show-current)
  gt up > /dev/null 2>&1
  AFTER=$(git branch --show-current)
  if [ "$BEFORE" = "$AFTER" ]; then exit 0; fi
done
