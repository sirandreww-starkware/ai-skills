---
description: "Submit the current PR or entire Graphite stack to the remote. Atomic skill used by other skills and directly by users."
---

# Submit

Push the current stack to the remote via Graphite.

## Usage

```bash
gt s --no-interactive --no-edit
```

## Pre-Submit Checks

Before submitting, verify the stack is in a clean state:

1. **Check for uncommitted changes:**
   ```bash
   git status --porcelain
   ```
   If there are unstaged changes, warn the user — they likely forgot to amend.

2. **Check restack status:**
   ```bash
   gt status
   ```
   If a restack is in progress or paused, do not submit. Resolve conflicts first with `/fix-stack-conflicts`.

## After Submitting

Report the result to the user. If `gt s` fails, show the error output.
