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

# Fetch all open PRs authored by me
PR_DATA=$(gh pr list --author "$MY_LOGIN" --state open --json number,title,url,headRefName,baseRefName --limit 100)
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

    REASONS=()

    # --- Check 1: Unresponded reviewer comments ---
    COMMENTS=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" --paginate 2>/dev/null || echo "[]")
    # Group by thread: root comments have no in_reply_to_id, replies reference the root
    # Find threads where the last comment is NOT by the PR author
    UNRESPONDED_THREADS=$(echo "$COMMENTS" | jq -r --arg me "$MY_LOGIN" '
        # Build threads: group by root comment id
        group_by(.in_reply_to_id // .id)
        | map(sort_by(.created_at))
        | map(select(length > 0))
        | map(select(.[-1].user.login != $me))
        | length
    ')
    if [ "$UNRESPONDED_THREADS" -gt 0 ]; then
        REASONS+=("Has $UNRESPONDED_THREADS unresponded review thread(s)")
    fi

    # --- Check 2: Latest commit fails CI ---
    # Get the status of the latest commit on the PR
    CI_STATE=$(gh pr checks "$PR_NUMBER" --json bucket --jq '[.[] | select(.bucket == "fail")] | length' 2>/dev/null || echo "0")
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
        echo "  Branch: $PR_HEAD -> $PR_BASE"
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
