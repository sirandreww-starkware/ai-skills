---
description: "Find open PRs that need your attention: unresponded reviews, CI failures, or multiple commits"
---

# Find PRs Needing Attention

Run the discovery script and present the results to the user.

## Steps

1. **Run the script:**
    ```bash
    ~/.claude/skills/attention-prs/scripts/find_prs.sh
    ```

2. **Present results:** Show the user which PRs were flagged and why. Group by urgency:
   - **CI failures** — these block merging
   - **Unresponded review comments** — these block approval
   - **Multiple commits** — these need squashing before merge

3. **Offer next steps:** Ask the user if they want to act on any of the flagged PRs (e.g., check out the branch, run `/bty` to address reviews, squash commits).
