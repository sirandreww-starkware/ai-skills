#!/usr/bin/env bash
# Fetch PR review threads for the current branch.
# Outputs JSON array of threads.
# Each thread: {thread_id, path, line, side, resolved, comments: [{author, body, created_at}]}
#
# Flags:
#   -a, --all            Show all threads (including ones the author already replied to)
#   -r, --resolved       Include resolved threads (by default, only unresolved threads are shown)
#   --no-bots            Exclude threads where every comment is from a bot
#   -b, --branch NAME    Branch to check (default: current branch)
#
# Default (no flags): show unresolved threads where the last comment is NOT by the PR author.
# Requires: gh CLI, jq

set -euo pipefail

# Parse flags
SHOW_ALL=false
INCLUDE_RESOLVED=false
NO_BOTS=false
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--all)        SHOW_ALL=true; shift ;;
    -r|--resolved)   INCLUDE_RESOLVED=true; shift ;;
    --no-bots)       NO_BOTS=true; shift ;;
    -b|--branch)     BRANCH="$2"; shift 2 ;;
    -*)              echo "Unknown flag: $1" >&2; exit 1 ;;
    *)               BRANCH="$1"; shift ;;  # positional arg = branch
  esac
done

BRANCH="${BRANCH:-$(git branch --show-current)}"

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

# Fetch issue comments (Reviewable sometimes posts threaded replies here)
ISSUE_COMMENTS=$(gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" --paginate 2>/dev/null || echo "[]")

# Process inline comments: group by thread, tag with resolved status
INLINE_THREADS=$(echo "$COMMENTS" | jq -r --arg me "$MY_LOGIN" --argjson resolved "$RESOLVED_IDS" \
  --argjson show_all "$SHOW_ALL" --argjson include_resolved "$INCLUDE_RESOLVED" --argjson no_bots "$NO_BOTS" '
  # Group comments into threads by root comment id
  group_by(.in_reply_to_id // .id)
  | map(sort_by(.created_at))
  # Filter by actionable (last comment not by author) unless --all
  | if $show_all then . else map(select(.[-1].user.login != $me)) end
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
  # Filter resolved unless --resolved
  | if $include_resolved then . else map(select(.resolved | not)) end
  # Filter bot-only threads if --no-bots
  | if $no_bots then map(select(.comments | map(.author | test("\\[bot\\]$")) | all | not)) else . end
')

# Process Reviewable threads from reviews and issue comments.
# Reviewable posts replies as separate GitHub reviews OR issue comments. We normalize
# both into a single stream, then group into threads by extracting the Reviewable
# discussion ID from URLs in each ___-separated section.
REVIEW_THREADS=$(jq -n --argjson reviews "$REVIEWS" --argjson issue_comments "$ISSUE_COMMENTS" \
  --arg me "$MY_LOGIN" --argjson show_all "$SHOW_ALL" --argjson no_bots "$NO_BOTS" '
  # Normalize reviews and issue comments into a uniform list of {author, time, body}
  [
    ($reviews[] | select(.body != null and .body != "" and .state != "PENDING") |
      {author: .user.login, time: .submitted_at, body: .body}),
    ($issue_comments[] | select(.body != null and .body != "") |
      {author: .user.login, time: .created_at, body: .body})
  ] |
  # Split each body into per-discussion sections and tag with metadata.
  # Reviews have a header before the first ___ separator; issue comments may not.
  # If no ___ exists, treat the entire body as a single section.
  [.[] |
    .author as $author | .time as $time |
    (.body | split("___")) |
    (if length > 1 then .[1:][] else .[0] end) |
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
  # Filter by actionable (last comment not by author) unless --all
  if $show_all then . else map(select(.[-1].author != $me)) end |
  # Format to match existing output structure
  map({
    thread_id: .[0].thread_id,
    path: .[0].path,
    line: .[0].line,
    side: null,
    comments: [.[] | {author, body, created_at: .submitted_at}]
  }) |
  # Filter bot-only threads if --no-bots
  if $no_bots then map(select(.comments | map(.author | test("\\[bot\\]$")) | all | not)) else . end
')

# Merge both sets
echo "$INLINE_THREADS" "$REVIEW_THREADS" | jq -s 'add // []'
