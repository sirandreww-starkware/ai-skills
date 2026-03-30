#!/usr/bin/env bash
# Find PRs authored by the current user that need attention.
# Flags:
#   1. Unresponded reviewer comments (last comment in thread is not by author)
#   2. Latest commit fails CI
#   3. More than one commit in PR history
#
# Usage: find_prs.sh [MAX_COUNT]
#   MAX_COUNT: optional, stop after reporting this many flagged PRs (default: unlimited)

set -euo pipefail

MAX_COUNT="${1:-0}"  # 0 means unlimited

OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
OWNER="${OWNER_REPO%/*}"
REPO="${OWNER_REPO#*/}"
MY_LOGIN=$(gh api user --jq '.login')

# Fetch all open PRs authored by me, sorted closest-to-main first.
# PRs based on main have depth 0, PRs based on those have depth 1, etc.
#
# Graphite rewrites some PRs' baseRefName to "graphite-base/N" (where N is the
# PR's own number).  This breaks the branch-chain depth computation because no
# PR has "graphite-base/N" as its headRefName.  To fix this we:
#   1. Fetch headRefOid for each PR
#   2. Bulk-fetch all graphite-base/* remote refs
#   3. Resolve graphite-base/N → SHA → parent PR's headRefName
PR_DATA_RAW=$(gh pr list --author "$MY_LOGIN" --state open \
  --json number,title,url,headRefName,baseRefName,headRefOid --limit 100)

# Build a JSON array of {ref, sha} for graphite-base/* branches.
GRAPHITE_REFS=$(git ls-remote origin 'refs/heads/graphite-base/*' 2>/dev/null \
  | jq -Rs '[split("\n") | .[] | select(length > 0)
    | split("\t") | {sha: .[0], ref: (.[1] | ltrimstr("refs/heads/"))}]')

PR_DATA=$(echo "$PR_DATA_RAW" | jq --argjson grefs "$GRAPHITE_REFS" '
  # Map SHA → headRefName so we can resolve graphite-base refs to parent branches
  (map({(.headRefOid): .headRefName}) | add // {}) as $sha_to_branch |
  # Map graphite-base/N → SHA
  ($grefs | map({(.ref): .sha}) | add // {}) as $gbase_to_sha |
  # Resolve graphite-base/N baseRefName to the actual parent branch name
  map(
    if (.baseRefName | test("^graphite-base/")) then
      ($gbase_to_sha[.baseRefName] // null) as $parent_sha |
      if $parent_sha then
        .baseRefName = ($sha_to_branch[$parent_sha] // .baseRefName)
      else . end
    else . end
  ) |
  # Build a map from branch name to base branch
  (map({(.headRefName): .baseRefName}) | add // {}) as $bases |
  # Compute stack depth: walk baseRefName chain until we hit a non-PR branch (e.g. main)
  def depth(branch):
    if $bases[branch] then 1 + depth($bases[branch]) else 0 end;
  map(. + {stack_depth: depth(.headRefName)})
  | sort_by(.stack_depth)
')
PR_COUNT=$(echo "$PR_DATA" | jq length)

if [ "$PR_COUNT" -eq 0 ]; then
    echo "No open PRs found."
    exit 0
fi

FLAGGED_ANY=false
FLAGGED_COUNT=0

for i in $(seq 0 $((PR_COUNT - 1))); do
    PR_NUMBER=$(echo "$PR_DATA" | jq -r ".[$i].number")
    PR_TITLE=$(echo "$PR_DATA" | jq -r ".[$i].title")
    PR_URL=$(echo "$PR_DATA" | jq -r ".[$i].url")
    PR_HEAD=$(echo "$PR_DATA" | jq -r ".[$i].headRefName")
    PR_BASE=$(echo "$PR_DATA" | jq -r ".[$i].baseRefName")
    STACK_DEPTH=$(echo "$PR_DATA" | jq -r ".[$i].stack_depth")

    REASONS=()

    # --- Check 1: Unresponded reviewer comments (skip resolved threads) ---
    # gh api --jq does not support --arg, so pipe to jq separately.
    UNRESPONDED_THREADS=$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100) {
              nodes {
                isResolved
                comments(first: 100) {
                  nodes { author { login } }
                }
              }
            }
          }
        }
      }' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER" \
      2>/dev/null | jq --arg me "$MY_LOGIN" '
        .data.repository.pullRequest.reviewThreads.nodes
        | map(select(.isResolved == false))
        | map(select(.comments.nodes | length > 0))
        | map(select(.comments.nodes[-1].author.login != $me))
        | length
      ' 2>/dev/null || echo "0")
    if [ "$UNRESPONDED_THREADS" -gt 0 ]; then
        REASONS+=("Has $UNRESPONDED_THREADS unresponded review thread(s)")
    fi

    # --- Check 2: Latest commit fails CI ---
    # gh pr checks does not support --json on gh <2.49; parse text output instead.
    # gh pr checks exits 1 when checks fail, so || true prevents pipefail from
    # triggering the outer fallback and producing a multi-line value.
    # Ignore merge-gatekeeper (downstream-only, fails when other checks fail)
    # and stale/skipped runs (zero duration).
    CI_STATE=$( (gh pr checks "$PR_NUMBER" 2>/dev/null || true) | awk -F'\t' '$2 == "fail" && $1 !~ /merge-gatekeeper/ && $3 != "0"' | wc -l)
    if [ "$CI_STATE" -gt 0 ]; then
        REASONS+=("CI failing ($CI_STATE check(s) failed)")
    fi

    # --- Check 3: More than one commit ---
    COMMIT_COUNT=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/commits" --jq 'length' 2>/dev/null || echo "1")
    if [ "$COMMIT_COUNT" -gt 1 ]; then
        REASONS+=("Has $COMMIT_COUNT commits (expected 1)")
    fi

    # --- Report ---
    if [ ${#REASONS[@]} -gt 0 ]; then
        FLAGGED_ANY=true
        FLAGGED_COUNT=$((FLAGGED_COUNT + 1))
        echo "========================================"
        echo "PR #$PR_NUMBER: $PR_TITLE"
        echo "  URL: $PR_URL"
        echo "  Branch: $PR_HEAD -> $PR_BASE (stack depth: $STACK_DEPTH)"
        echo "  Reasons:"
        for reason in "${REASONS[@]}"; do
            echo "    - $reason"
        done
        echo ""
        if [ "$MAX_COUNT" -gt 0 ] && [ "$FLAGGED_COUNT" -ge "$MAX_COUNT" ]; then
            break
        fi
    fi
done

if [ "$FLAGGED_ANY" = false ]; then
    echo "All PRs look good - nothing needs your attention."
fi
