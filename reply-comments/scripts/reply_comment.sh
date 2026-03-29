#!/usr/bin/env bash
# Reply to a PR review comment via the GitHub API.
# Replies posted here appear in both GitHub and Reviewable.
#
# Usage:
#   reply_comment.sh inline <COMMENT_ID> <BODY>       # inline review comment (path != null)
#   reply_comment.sh top-level <REVIEW_ID> <BODY>      # top-level Reviewable discussion (path == null)
#
# The type MUST match the comment kind from fetch_comments.sh output:
#   - path != null  → use "inline"
#   - path == null   → use "top-level"
#
# Auto-detects PR number from current branch and owner/repo from gh.

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: reply_comment.sh <inline|top-level> <COMMENT_ID> <BODY>" >&2
  echo "  inline:    for file-level review comments (path != null)" >&2
  echo "  top-level: for Reviewable discussions (path == null)" >&2
  exit 1
fi

TYPE="$1"
COMMENT_ID="$2"
BODY="$3"

if [ "$TYPE" != "inline" ] && [ "$TYPE" != "top-level" ]; then
  echo "Error: first argument must be 'inline' or 'top-level', got '$TYPE'" >&2
  exit 1
fi

OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BRANCH=$(git branch --show-current)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')

if [ -z "$PR_NUMBER" ] || [ "$PR_NUMBER" = "null" ]; then
  echo "No open PR found for branch $BRANCH" >&2
  exit 1
fi

if [ "$TYPE" = "top-level" ]; then
  echo "Error: top-level Reviewable discussions cannot be replied to via the GitHub API." >&2
  echo "Reviewable maintains its own server-side threading — replies posted through GitHub" >&2
  echo "won't thread correctly. Reply to this comment directly in Reviewable instead." >&2
  echo "Review ID: $COMMENT_ID" >&2
  echo "Reviewable link: https://reviewable.io/reviews/$OWNER_REPO/$PR_NUMBER" >&2
  exit 1
fi

# Inline review comment reply. Fails hard on error.
RESULT=$(gh api "repos/$OWNER_REPO/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
  -f body="$BODY" \
  --jq '.id')
echo "$RESULT"
echo "Reply posted to comment $COMMENT_ID on PR #$PR_NUMBER"
