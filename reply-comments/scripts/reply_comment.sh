#!/usr/bin/env bash
# Reply to a PR review comment via the GitHub API.
# Replies posted here appear in both GitHub and Reviewable.
# Usage: reply_comment.sh <COMMENT_ID> <BODY>
#   COMMENT_ID: the id of the review comment to reply to
#   BODY: the reply text
# Auto-detects PR number from current branch and owner/repo from gh.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: reply_comment.sh <COMMENT_ID> <BODY>" >&2
  exit 1
fi

COMMENT_ID="$1"
BODY="$2"
OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BRANCH=$(git branch --show-current)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')

if [ -z "$PR_NUMBER" ] || [ "$PR_NUMBER" = "null" ]; then
  echo "No open PR found for branch $BRANCH" >&2
  exit 1
fi

gh api "repos/$OWNER_REPO/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
  -f body="$BODY" \
  --jq '.id' 2>&1

echo "Reply posted to comment $COMMENT_ID on PR #$PR_NUMBER"
