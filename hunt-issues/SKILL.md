---
name: hunt-issues
description: "Hypothesis-driven bug hunt. Read the code, theorize ONE specific issue, write a NEW test that FAILS only if that issue is real, and let the test be the judge: refuted theories get the test deleted and you move on; confirmed theories keep the failing test, then you fix the code, make the test pass, and commit explaining the issue and fix. Use when the user says 'hunt for bugs', 'hunt for issues', 'find bugs/vulnerabilities', 'look for issues in this code/PR/stack/feature', or wants adversarial test-driven bug hunting."
argument-hint: "[target: file | dir | PR | stack | feature | (default: current branch diff)]"
---

# Hunt Issues

Adversarial, test-driven bug hunting. You are trying to **break** the code, not bless it. The
deliverable is not a list of opinions — it is a set of *failing tests that you then turn green by
fixing real bugs*, plus an honest ledger of theories you tried and disproved.

## Core principle: the test is the judge, not you

A theory you cannot express as a failing test is **not a finding — it is a guess.** LLMs are
confidently wrong about bugs all the time. This skill exists to force every suspicion through a
falsification gate:

> Write a test that asserts the **correct** behavior. Run it.
> - It **fails on the assertion you predicted** → the bug is real. Keep the test, fix the code.
> - It **passes** → your theory was wrong. Delete the test. Move on. No rationalizing.

Never weaken an assertion, change expected values to match buggy output, or `#[ignore]` a test to
manufacture a "finding." If you find yourself arguing with a passing test, the code is right and you
are wrong.

## Step 0: Scope the hunt

Figure out exactly what code is in scope before theorizing. Match the target the user gave you:

| Target | How to scope it |
|---|---|
| **A file / module** | Read it fully, plus its direct callers and callees. |
| **Current branch / PR** | `git diff <base>...HEAD` (often `main...HEAD`). Hunt the changed lines *and* the code they newly interact with. |
| **A stack of PRs** | Walk each PR's diff bottom-to-top (`git log`/`gt log`); a bug may live in the interaction *between* stacked changes, not any single one. |
| **A feature** | Find every file implementing it (grep for the entry points, types, config keys), then read the data flow end to end. |
| **"The codebase"** | Ask the user to narrow it, or pick the highest-risk subsystem (auth, money, state machines, concurrency, parsing untrusted input) and start there. |

Then **understand it before attacking it.** Read until you can state, in one sentence each:
- What is this code's contract — what must always be true when it returns?
- What are its inputs and their valid/invalid ranges?
- What does it assume about its callers, the order of calls, and the world (time, network, files)?

If the target is ambiguous, confirm scope with the user before spending hours.

**Build the coverage map and set the budget.** The scoped units (files / functions / changed hunks)
crossed with the bug classes in *Where to aim* form a **coverage matrix** — track each cell as
`tested`, `skipped (reason)`, or `pending`. This map, not your gut, tells you when the hunt is done.
If the user named a ceiling — a time window, a max number of theories, a target count of confirmed
bugs — record it as a hard cap. If they didn't, the default is **full coverage, then check in**: work
the whole matrix once with no count or clock cap, then stop and report.

**Resume prior hunts, and seed the search — so repeat runs diverge.** Running this skill twice on the
same code must not re-walk the same path. Sampling temperature won't prevent that: the model's prior
re-proposes the same "obvious" theory first. Two mechanisms, both set up here:

- *Cross-run memory (the real lever).* Persist the ledger + coverage map at
  `.git/hunt-issues/ledger.jsonl` — under `.git/`, so it's auto-untracked and never pollutes history.
  (Non-git repo: fall back to `.hunt-issues/` and tell the user to gitignore it.) On startup **load
  it**, and also scan `git log` for prior hunt/bug-fix commits; mark every already-`tested`,
  `skipped`, or confirmed cell **off-limits** and resume into the `pending` cells. Run 2 then *can't*
  re-propose run 1's theories — it starts where run 1 stopped, so runs accumulate coverage instead of
  repeating.
- *Seeded entry point.* Even among the unexplored cells you have a favorite starting point. Break it
  by pulling a seed from **outside** the model — `git rev-parse HEAD`, `date +%s%N`, or `$RANDOM`
  (or a user-supplied seed) — **log the seed** for reproducibility, and use `seed % len(...)` to pick
  which unit / bug class / lens you lead with. Different seed → a different branch of the search tree
  unrolls first.

If, after loading prior runs, the only theories you can form are already in the ledger, the search
space is genuinely exhausted — report that (Step 7 exit); don't re-roll to look busy.

## Step 1: Theorize ONE specific issue

Pick a single, concrete, falsifiable theory. Bad: "error handling might be off." Good: "if the
required-checks list is empty, the gatekeeper approves the merge (fails open) instead of blocking."

A good theory names: the **input/condition**, the **wrong behavior** you expect, and the **correct
behavior** it violates. If you can't name all three, keep reading — you don't understand it yet.

Aim theories at the high-yield bug classes (see **Where to aim** below). Work them roughly in order
of blast radius: a fail-open security gate beats a cosmetic off-by-one.

## Step 2: Write a NEW test that encodes the correct behavior

- Put it in a **new, clearly named test file** (e.g. `hunt_<area>_<theory>_test.<ext>`) so it's
  trivial to keep or delete without disturbing existing tests.
- The test **sets up the theorized condition** and **asserts the behavior the contract requires**
  (the correct outcome), not the behavior you suspect the code actually produces.
- Keep it minimal and deterministic — one theory, one assertion focus. No sleeps, no real network,
  no shared state.
- For **security** theories, the test is a proof-of-concept: set up the attack precondition and
  assert that the defense holds (request denied, input rejected, data not leaked).

## Step 3: Run it and triage the result

Run the **narrowest invocation** that executes just this test (e.g. `cargo test <name>`,
`pytest path::test`, `jest -t`, `go test -run`). Three outcomes — triage honestly:

1. **Fails on the predicted assertion** → theory **confirmed**. The bug is real. Go to Step 4.
2. **Fails for an unrelated reason** (won't compile, wrong fixture, panic in setup, bad import) →
   the *test* is broken, not the code. Fix the test and re-run. A test that never cleanly exercised
   the assertion confirms nothing.
3. **Passes** → theory **refuted**. Delete the test file, log the refuted theory (Step 7), return to
   Step 1 with a new theory.

Before declaring a confirmed bug, **read the actual failure output** and verify it fails *because of
the reason you theorized*. A right answer for the wrong reason is still a wrong test.

Also rule out **intended behavior**: check docs, comments, and existing tests. If the "bug" is a
documented, tested decision, it's not a bug — log it and move on, or raise it with the user if it
still seems wrong.

## Step 4: Keep the failing test, fix the root cause

With a confirmed, red test:
- Fix the **root cause**, not the symptom. Don't patch the one input the test uses; fix the logic so
  the whole class of inputs is correct.
- **Never edit the test to match the buggy code.** The test defines correct; the code moves to meet it.
- Make the minimal change that satisfies the contract. Resist scope creep into unrelated refactors.

## Step 5: Make it green — and prove no regression

- Re-run the new test → it must **pass**.
- Run the **surrounding suite** (the module's tests, the crate/package's tests) → everything that
  passed before must still pass. A fix that turns one test green and another red isn't done.
- If the fix changed behavior other tests depended on, decide whether *those* tests encoded the bug
  (update them, and say so in the commit) or whether your fix is wrong (rethink it).

## Step 6: Record the issue + its fix — using the repo's version control

One **atomic commit per confirmed-and-fixed issue**, containing both the new test and the fix — so
the commit is self-contained proof: the test demonstrates the bug, the fix resolves it. **How** you
commit depends on the repo's version control — detect it once, then reuse the answer for the whole hunt:

| Repo uses… | How to commit | Detect with |
|---|---|---|
| **Graphite** | `gt c` (create a Graphite-tracked commit; never bare `git commit`) | `gt` on PATH **and** `.git/.graphite_repo_config` exists (or `gt repo` succeeds) |
| **Plain git** | `git commit` | `.git/` exists but no Graphite config |
| **No version control** | **Don't commit.** Keep the test + fix in the working tree and keep hunting. | no `.git/` |

Follow the repository's commit conventions and any user commit preferences (subject style, trailers).
Write the message so a reviewer understands the bug without re-deriving it:
- **Subject:** one concise line naming the issue (e.g. `gatekeeper: fail closed when no required checks`).
- **Body:** (1) the theorized issue and the condition that triggers it, (2) the wrong behavior vs.
  the contract it violated, (3) what the new test asserts, (4) the fix.

> Optional red→green history: if the user wants the bug *demonstrated* in history, commit the failing
> test first, then the fix as a second commit. Default to a single atomic commit, since most CI/bisect
> setups expect every commit to be green.
>
> No version control means nothing to commit to — don't initialize a repo, don't stash; just leave
> the change in place, note it in the ledger, and move to the next theory.

## Step 7: Log it and loop

Maintain a running **theory ledger** in your response so the user can follow the hunt and you don't
repeat yourself — and persist each resolved row to the cross-run ledger from Step 0
(`.git/hunt-issues/ledger.jsonl`, one JSON record: seed, unit, bug class, theory, verdict,
evidence/commit) so the *next* run resumes from it instead of re-treading:

```
## Theory Ledger
| # | Theory (input → wrong behavior) | Verdict   | Evidence                          |
|---|---------------------------------|-----------|-----------------------------------|
| 1 | empty required-checks → approves| CONFIRMED | hunt_gate_empty_test → fixed @abc |
| 2 | check name case-sensitive match | REFUTED   | test passed; match is normalized  |
| 3 | concurrent status update race   | hunting…  | —                                 |
```

Return to Step 1, updating the coverage map as you go. A run of refutations in one area is **not** a
reason to stop — a dry streak says nothing about unexplored cells, and "stop after N refutations"
just tempts you to pad the count with weak theories. Treat it as a signal to **switch area or bug
class**, not to quit.

### When to stop

- **Done (primary signal):** the coverage map is exhausted — every scoped unit × relevant bug class
  is `tested` or `skipped (reason)`. This is the principled definition of done.
- **Ceiling (if the user set one):** the budget — time window / max theories / target confirmed-bug
  count — is hit. Stop even if coverage is incomplete, and say exactly what's left unexamined.
- **No ceiling set:** the default is *full coverage, then check in* — run the whole matrix once, no
  count or clock cap.

### Stay in the loop — check in, don't run silently for hours

This is an open-ended task; the human should stay in the loop. **Pause and surface the ledger +
coverage map** after each confirmed-and-fixed bug and whenever a coverage area completes, and let the
user steer: keep-going / stop / refocus on area X.

### Exit report — never declare "all clear"

Absence of confirmed bugs is **not** proof the code is correct. End every hunt with an honest report:
coverage achieved, confirmed-and-fixed count, refuted theories, and — explicitly — **what was not
examined and why** (out of budget, skipped with reason, out of scope). Never write "no bugs found"
without that qualification.

## Where to aim theories (bug-class checklist)

Walk these systematically against the scoped code — each row is a theory generator:

- **Boundaries:** empty / single / max / off-by-one; first & last iteration; empty collection, `len-1`.
- **Fail-open vs. fail-closed:** when a check, config, or list is missing/empty, does a *gate* default
  to allow? Does an error path skip the security check? (Classic in gatekeepers, authz, validators.)
- **Error handling:** swallowed errors, `unwrap`/`expect`/`!` on fallible paths, partial failure
  leaving inconsistent state, error in cleanup masking the real error.
- **None/null/default:** `Option`/`null`/zero-value treated as valid; missing key vs. present-but-empty.
- **State machines & ordering:** illegal transitions, calls out of expected order, re-entry,
  double-init, use-after-close, idempotency (does calling twice double-apply?).
- **Concurrency:** TOCTOU, races between check and act, lock not held across a read-modify-write,
  assumption that a value can't change between two reads.
- **Numeric:** integer overflow/underflow/wraparound, signed/unsigned, truncating casts, division by
  zero, float equality, rounding.
- **Input validation / security:** injection (SQL/command/path), missing authz check on a code path,
  trusting client-supplied IDs, unescaped output, deserialization of untrusted data, secrets in logs.
- **Time & resources:** timezone/DST, clock going backward, timeouts, leaked handles/connections,
  unbounded growth, retries without backoff or cap.
- **Comparisons & matching:** case sensitivity, normalization (Unicode, trailing slash, trailing
  whitespace), `==` vs. `equals`, substring vs. exact match, locale-dependent sort.
- **Data integrity:** serialization round-trip loss, schema/version skew, silent data truncation.

## Tips & anti-patterns

- **One theory at a time.** A test that bundles three suspicions tells you nothing clean when it fails.
- **The hardest discipline is deleting a passing test.** Do it. A refuted theory is a successful
  experiment, not a failure — it shrinks the search space.
- **Don't trust a green run you didn't read.** Confirm a confirmed-bug test fails on *its* assertion;
  confirm a refuted-theory test actually ran (not skipped/filtered to zero tests).
- **Reproduce before you fix.** If you can't make the bug fail in a test, you don't understand it well
  enough to fix it — and you can't prove your fix worked.
- **Subtler bugs come later.** Early theories catch obvious things; once those are gone, hunt the
  interactions — between stacked PRs, between concurrent callers, between this change and old assumptions.
- **When stuck, invert:** instead of "is this correct?", ask "what input would make this catastrophically
  wrong?" and write the test for that input.
- **Report faithfully.** If you found nothing in scope, say so plainly and show the ledger of refuted
  theories — that's a real result, not a failure to perform.
