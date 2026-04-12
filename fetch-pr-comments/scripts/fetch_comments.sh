#!/usr/bin/env bash
# Fetch actionable PR review threads for the current branch.
# Outputs JSON array of threads where the last comment is NOT by the PR author.
# Each thread: {thread_id, path, line, side, resolved, comments: [{author, body, created_at}]}
# Usage: fetch_comments.sh
# Requires: gh CLI, jq

set -euo pipefail

BRANCH="${1:-$(git branch --show-current)}"

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

# Fetch resolution status per thread via GraphQL (REST API lacks this)
RESOLVED_IDS=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            comments(first: 1) {
              nodes { databaseId }
            }
          }
        }
      }
    }
  }' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUMBER" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved) | .comments.nodes[0].databaseId]' 2>/dev/null || echo "[]")

# Fetch inline review comments (these are the line-level comments)
COMMENTS=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" --paginate 2>/dev/null || echo "[]")

# Fetch top-level reviews (for review-level comments that aren't inline)
REVIEWS=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate 2>/dev/null || echo "[]")

# Process inline comments: group by thread, tag with resolved status
ACTIONABLE_THREADS=$(echo "$COMMENTS" | jq -r --arg me "$MY_LOGIN" --argjson resolved "$RESOLVED_IDS" '
  # Group comments into threads by root comment id
  group_by(.in_reply_to_id // .id)
  | map(sort_by(.created_at))
  # Keep threads where last comment is NOT by the PR author (actionable)
  | map(select(.[-1].user.login != $me))
  # Format each thread, tagging resolved status
  | map({
      thread_id: (.[0].in_reply_to_id // .[0].id),
      path: .[0].path,
      line: (.[0].original_line // .[0].line // .[0].position),
      side: (.[0].side // "RIGHT"),
      resolved: ((.[0].in_reply_to_id // .[0].id) as $root | ($resolved | index($root)) != null),
      comments: [.[] | {
        author: .user.login,
        body: .body,
        created_at: .created_at
      }]
    })
')

# Process top-level review comments (body-only reviews, not inline).
# Reviewable posts each reply as a separate GitHub review. We group them into
# threads by extracting the Reviewable discussion ID from URLs in each ___-separated
# section, then keep only threads where the last comment is NOT by the PR author.
REVIEW_COMMENTS=$(echo "$REVIEWS" | jq -r --arg me "$MY_LOGIN" '
  # Split each review body into per-discussion sections and tag with metadata
  [.[] | select(.body != null and .body != "" and .state != "PENDING") |
    .user.login as $author | .submitted_at as $time |
    (.body | split("___")) |
    .[1:][] |  # skip the header (before first ___)
    . as $section |
    # Extract Reviewable thread ID (first component of the #-<ID>:<ID>:<hash> fragment)
    (try ($section | capture("reviewable\\.io/reviews/[^#]+#(?<tid>[^:]+):") | .tid) // null) as $thread_id |
    select($thread_id != null) |
    # Extract file path and line if present (inline comments have `path` line N format)
    (try ($section | capture("\\*\\[`(?<path>[^`]+)` line (?<line>[0-9]+)")) // null) as $loc |
    {
      thread_id: $thread_id,
      author: $author,
      submitted_at: $time,
      body: $section,
      path: (if $loc then $loc.path else null end),
      line: (if $loc then ($loc.line | tonumber) else null end)
    }
  ] |
  # Group by Reviewable thread ID and sort each group chronologically
  group_by(.thread_id) | map(sort_by(.submitted_at)) |
  # Keep only threads where the last comment is NOT by the PR author
  map(select(.[-1].author != $me)) |
  # Format to match existing output structure
  map({
    thread_id: .[0].thread_id,
    path: .[0].path,
    line: .[0].line,
    side: null,
    comments: [.[] | {author, body, created_at: .submitted_at}]
  })
')

# Merge both sets
echo "$ACTIONABLE_THREADS" "$REVIEW_COMMENTS" | jq -s 'add // []'
