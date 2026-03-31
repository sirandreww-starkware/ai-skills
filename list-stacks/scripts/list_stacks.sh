#!/usr/bin/env bash
set -euo pipefail

GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "ERROR: Not in a git repo"; exit 1; }
CACHE="$GIT_DIR/.graphite_cache_persist"
[[ -f "$CACHE" ]] || { echo "ERROR: No Graphite cache found. Run 'gt ls' first to initialize."; exit 1; }

CURRENT=$(git branch --show-current 2>/dev/null || echo "")

jq -r --arg current "$CURRENT" '
  # Build lookup: name -> {parent, children}
  [.branches[] | {key: .[0], value: {parent: .[1].validationResult, children: (.[1].children // [])}}]
  | from_entries as $tree |

  # Find trunk (branch with parent == "TRUNK")
  ($tree | to_entries | map(select(.value.parent == "TRUNK")) | .[0].key) as $trunk |

  # Count all branches in a subtree
  def subtree_size:
    . as $name |
    1 + (($tree[$name].children) | map(subtree_size) | add // 0);

  # Check if $target exists anywhere in the subtree
  def has_branch($target):
    . as $name |
    if $name == $target then true
    elif ($tree[$name].children | length) == 0 then false
    else ($tree[$name].children | any(has_branch($target)))
    end;

  # Walk the linear chain (single-child path) from a branch
  def linear_chain:
    . as $name |
    if ($tree[$name].children | length) == 1
    then [$name] + ($tree[$name].children[0] | linear_chain)
    else [$name]
    end;

  # Count fork points in subtree
  def fork_count:
    . as $name |
    (if ($tree[$name].children | length) > 1 then 1 else 0 end) +
    (($tree[$name].children) | map(fork_count) | add // 0);

  # Process each root stack
  ($tree[$trunk].children) as $roots |

  if ($roots | length) == 0 then
    "No stacks found off \($trunk)."
  else
    "\($roots | length) stack(s) off \($trunk):\n" +
    ([$roots | to_entries[] |
      .value as $root |
      ($root | subtree_size) as $size |
      ($root | has_branch($current)) as $is_current |
      ($root | linear_chain) as $chain |
      ($root | fork_count) as $forks |
      ($chain | last) as $chain_end |
      ($tree[$chain_end].children | length) as $end_children |

      "Stack \(.key + 1): \($root)\n" +
      "  \($size) PRs" +
        (if $is_current then "  |  on: \($current)" else "" end) +
        (if $forks > 0 then "  |  \($forks) fork(s)" else "" end) +
      "\n  " +
      (if ($chain | length) <= 5
       then ($chain | join(" -> "))
       else (($chain[:3] | join(" -> ")) + " -> ... -> " + $chain[-1])
       end) +
      (if $end_children > 1
       then " -> [\($end_children) sub-stacks]"
       else ""
       end)
    ] | join("\n\n"))
  end
' "$CACHE"
