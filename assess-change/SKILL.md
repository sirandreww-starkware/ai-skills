---
name: assess-change
description: "Assess the impact of a proposed code change: draft a fix plan, count affected files/lines/crates, and recommend amend vs insert-pr. Read-only — does not modify code."
argument-hint: <review-comment-description> <file:line>
---

# Assess Change Impact

Given a review comment and the code it references, draft a concrete fix plan and measure the blast radius. This skill is **read-only** — it does not modify any files.

## Input

The caller provides:
- The review comment text (what the reviewer is asking for)
- The file path and line number the comment references
- The current PR's diff context (`git diff HEAD^`)

## Step 1: Understand the Request

Read the referenced file and surrounding context. Understand exactly what change the reviewer is requesting:
- Is it a rename (variable, function, type, file)?
- Is it a restructure (move code to a different module, split a function, extract a type)?
- Is it an API change (change a function signature, add/remove a parameter)?
- Is it a behavioral change (change logic, fix a bug, add validation)?

## Step 2: Trace the Blast Radius

Search the codebase to find everything affected by the proposed change:

1. **For renames:** Grep for all occurrences of the identifier across the codebase. Include:
   - Direct usages
   - References in comments and documentation
   - Re-exports and `use` statements
   - Test code

2. **For restructures:** Trace the module/item being moved:
   - All `use`/`mod` statements that import it
   - All files that reference the old path
   - Downstream crates that depend on the re-exported item

3. **For API changes:** Find all call sites:
   - Direct callers of the function/method
   - Trait implementations if the signature is on a trait
   - Test code that exercises the API

4. **For behavioral changes:** Identify scope:
   - Is the change local to one function?
   - Does it change a return type or error variant that callers match on?
   - Does it affect serialization/deserialization (wire format changes)?

## Step 3: Draft the Fix Plan

For each affected file, describe the specific change needed:

```
File: crates/foo/src/bar.rs
  - Line 42: rename `process_data` → `validate_input`
  - Line 87: update call site to use new name

File: crates/foo/src/tests/bar_test.rs
  - Line 15: update test helper call
  - Line 38: update assertion message
```

Be concrete — name the lines, the old text, and the new text where possible. This plan will be used later to apply the fix.

## Step 4: Produce the Assessment

Return a structured assessment:

```
Files affected: <N>
Estimated lines changed: <N>
Crates affected: <list>
Crosses crate boundaries: yes/no
Recommendation: amend | insert-pr
Reason: <one-line justification>

Plan:
<the fix plan from Step 3>
```

### Recommendation Heuristics

Recommend **insert-pr** when ANY of:
- More than 5 files affected
- Crosses crate boundaries (changes in 2+ crates)
- Involves a file rename or move
- Estimated lines changed > 50

Recommend **amend** when ALL of:
- 5 or fewer files affected
- Changes stay within a single crate
- No file renames or moves
- Estimated lines changed ≤ 50

These are suggestions — the user makes the final call.
