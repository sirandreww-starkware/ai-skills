#!/usr/bin/env bash
# Fetch actionable PR review threads for the current branch.
# Outputs JSON array of threads where the last comment is NOT by the PR author.
# Each thread: {thread_id, path, line, side, comments: [{author, body, created_at}]}
# Usage: fetch_comments.sh
# Requires: gh CLI, jq

set -euo pipefail

BRANCH=$(git branch --show-current)

# Find the PR for this branch
PR_JSON=$(gh pr list --head "$BRANCH" --json number,author --limit 1)
PR_COUNT=$(echo "$PR_JSON" | jq length)
if [ "$PR_COUNT" -eq 0 ]; then
  echo "No open PR found for branch $BRANCH" >&2
  exit 1
fi

PR_NUMBER=$(echo "$PR_JSON" | jq -r '.[0].number')
MY_LOGIN=$(echo "$PR_JSON" | jq -r '.[0].author.login')
OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
OWNER="${OWNER_REPO%/*}"
REPO="${OWNER_REPO#*/}"

# Fetch inline review comments (these are the line-level comments)
COMMENTS=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" --paginate 2>/dev/null || echo "[]")

# Fetch top-level reviews (for review-level comments that aren't inline)
REVIEWS=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate 2>/dev/null || echo "[]")

# Process inline comments: group by thread, filter for actionable threads
ACTIONABLE_THREADS=$(echo "$COMMENTS" | jq -r --arg me "$MY_LOGIN" '
  # Group comments into threads by root comment id
  group_by(.in_reply_to_id // .id)
  | map(sort_by(.created_at))
  # Keep threads where last comment is NOT by the PR author (actionable)
  | map(select(.[-1].user.login != $me))
  # Format each thread
  | map({
      thread_id: (.[0].in_reply_to_id // .[0].id),
      path: .[0].path,
      line: (.[0].original_line // .[0].line // .[0].position),
      side: (.[0].side // "RIGHT"),
      comments: [.[] | {
        author: .user.login,
        body: .body,
        created_at: .created_at
      }]
    })
')

# Process top-level review comments (body-only reviews, not inline)
REVIEW_COMMENTS=$(echo "$REVIEWS" | jq -r --arg me "$MY_LOGIN" '
  [.[] | select(.body != null and .body != "" and .state != "PENDING" and .user.login != $me) | {
    thread_id: .id,
    path: null,
    line: null,
    side: null,
    comments: [{
      author: .user.login,
      body: .body,
      created_at: .submitted_at
    }]
  }]
')

# Merge both sets
echo "$ACTIONABLE_THREADS" "$REVIEW_COMMENTS" | jq -s 'add // []'
