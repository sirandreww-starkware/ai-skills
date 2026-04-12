#!/usr/bin/env bash
# Show what upstack PRs change in the same files as the current PR.
# Use this BEFORE making fixes to check if the work is already done above.
set -euo pipefail

# Step 1: Get files changed in the current PR.
pr_files=$(git diff HEAD^ --name-only | sort -u)
if [[ -z "$pr_files" ]]; then
    echo "No files changed in current PR."
    exit 0
fi

# Step 2: Find the top branch of the stack.
stack_output=$(gt ls -s 2>/dev/null)
current_branch=$(git branch --show-current)
top_branch=$(echo "$stack_output" | sed -n 's/^[◯◉●]  *//p' | head -1)

if [[ -z "$top_branch" || "$top_branch" == "$current_branch" ]]; then
    echo "No upstack PRs — current branch is the top of the stack."
    exit 0
fi

# Step 3: Show upstack diff scoped to this PR's files.
echo "Current branch: $current_branch"
echo "Top of stack:   $top_branch"
echo ""
echo "Files changed in this PR:"
echo "$pr_files" | sed 's/^/  /'
echo ""

mapfile -t file_array <<< "$pr_files"
upstack_diff=$(git diff "HEAD..${top_branch}" -- "${file_array[@]}")

if [[ -z "$upstack_diff" ]]; then
    echo "No overlap — upstack PRs do not touch any of this PR's files."
    exit 0
fi

echo "=== Upstack changes to this PR's files ==="
echo ""
echo "$upstack_diff"
