---
name: codestyle-review
description: "Review Rust code changes against the team's Rust Coding Conventions (51 rules covering file layout, error handling, async patterns, type safety, documentation, casting, imports, and more). Use when the user says 'codestyle review', 'codestyle-review', 'rust review', 'check rust conventions', 'review code style', or wants a thorough convention check before submitting a PR."
argument-hint: "[file-or-branch]"
---

# Codestyle Review

Review the code changes specified by `$ARGUMENTS` (defaults to staged + unstaged Rust changes) against the Rust Coding Conventions below. Apply every rule; report every violation.

For each violation found, output:

1. **File and line**
2. **Rule violated** (reference the rule's number and short name)
3. **What's wrong** (one sentence)
4. **Suggested fix** (concrete)

Group findings by file. At the end, summarize the total count per rule.

## Scope

Default: staged + unstaged Rust changes.

Argument handling for `$ARGUMENTS`:
- Path (file or directory) → review just that path.
- Branch name → diff against `main`.
- Literal `HEAD` or a commit ref → diff against the parent of HEAD.
- Empty → staged + unstaged Rust changes (`git diff HEAD`).

Gather the list of changed `.rs` files and any `Cargo.toml` files (rule 35 needs Cargo.toml), and the full unified diff with generous context:

```bash
# Default scope:
git diff HEAD --name-only -- '*.rs' 'Cargo.toml' '**/Cargo.toml'
git diff HEAD -U10 -- '*.rs' 'Cargo.toml' '**/Cargo.toml'
```

If the scope is empty, print `Codestyle review: no Rust changes to review.` and stop.

Read each changed file in full (use the Read tool on each path) — many rules require seeing surrounding context, not just the diff. Focus on lines that are added or modified in the diff. Pre-existing violations on unchanged lines should be flagged only if directly impacted by the change.

## Rules

The complete list — apply each one when reading the changed files.

---

#### 1. File Layout — Importance and Top-Down Ordering

**Rule:** Items in a `.rs` file are ordered by importance (what a likely reader is looking for) and top-down: `mod` declarations and `use` statements first; then the public API; then the private functions the public API calls; then *their* helpers; and so on. In test files (`*_test.rs`, `tests/*.rs`), tests appear first and helper functions at the bottom.

**Flag:**
- Imports/`mod` declarations not at the top of the file.
- Private helpers defined above the public API they support.
- A function defined before any of its callers (when both are in the same file and there's no continuity reason).
- Test files where helper functions appear above tests.

**Don't flag** when the inversion preserves continuity:
- All methods of a struct in the same `impl` block (mixed pub/priv is fine).
- Semantically related functions grouped together.
- A struct `Bar` defined before `Foo` because `Foo` is hard to understand without `Bar` (even though `Foo` contains `Bar`).

---

#### 2. Module File Naming

**Rule:** A single-file module lives in `foo.rs`. A module with submodules is declared in `foo/mod.rs`, and `mod.rs` should contain ONLY submodule declarations (no functions, types, constants, or non-trivial logic). General-purpose code that doesn't belong to a specific submodule goes in `foo/foo.rs`, not `foo/mod.rs`.

**Flag:**
- Any `mod.rs` containing functions, types, constants, or implementation logic beyond `mod` / `pub mod` declarations and (optionally) re-exports.
- Module-level general code placed in `mod.rs` instead of `<module>/<module>.rs`.

**Don't flag** simple `pub use` re-exports in `mod.rs`.

---

#### 3. Test File Placement and Naming

**Rule:**
- For `foo.rs`, tests go in `foo_test.rs` in the same directory, and `foo.rs` declares it as `#[cfg(test)] #[path = "foo_test.rs"] mod foo_test;` so tests can access private items.
- For `foo/mod.rs`, tests go in `foo/test.rs`.
- Multiple test files are allowed; each must end with the `_test` suffix.
- For single-file modules, additional test files must also start with the module's prefix (e.g., `foo_flow_test.rs`, `foo_regression_test.rs`).

**Flag:**
- Tests defined inline inside `foo.rs` (`#[cfg(test)] mod tests { ... }` with bodies) instead of a sibling `foo_test.rs`.
- Sibling test file present without the `#[path]` attribute in the source file.
- Test files not ending in `_test` (e.g., `foo_tests.rs`, `foo_test_misc.rs`).
- Multiple test files for `foo.rs` not prefixed with `foo_`.

---

#### 4. Crate Names Use Underscores

**Rule:** Crate names use underscores (`_`), not hyphens (`-`), in BOTH the directory name AND the `name` field of `Cargo.toml`.

**Flag:**
- Any new or renamed `Cargo.toml` whose `[package].name` contains a hyphen.
- Any new crate directory whose name contains a hyphen.

---

#### 5. Deprecated and Toy Crates

**Rule:** Avoid crates that have been superseded by `std`/the language: `lazy_static` (use `std::sync::OnceLock` / `LazyLock`), `async_trait` (use native `async fn` in traits). Avoid "toy" crates with low GitHub stars or that look like personal projects rather than production-ready libraries.

**Flag:**
- Any new `lazy_static!` macro invocation.
- Any new `#[async_trait]` attribute on a trait.
- Any new dependency added in `Cargo.toml` on a crate known to be unmaintained or "toy" (use judgement; prefer flagging unfamiliar low-profile crates so the reviewer can confirm).

---

#### 6. Hygiene — Leaks, Races, Excessive Allocations, Conflict Resolution

**Rule:** Watch for hygiene issues that AI-generated code commonly introduces: leaks (detached tasks, leaked file descriptors, leaked temp files), race conditions (concurrent access without proper synchronization, holding a `Mutex`/`RwLock` guard across `.await`), excessive `.clone()` and `Vec` allocations where a borrow or iterator would do, and merge-conflict resolutions that blindly took one side without analyzing the change.

**Flag:**
- `tokio::spawn(...)` whose `JoinHandle` is dropped or assigned to `_` without a comment justifying detachment.
- A `Mutex`/`RwLock` guard held across an `.await` point.
- `.clone()` calls that look unnecessary (cloning a `Vec` only to read it; cloning before passing to a function that takes `&T`).
- Building a `Vec` only to immediately iterate it once and drop it, where a chained iterator would suffice.
- Merge-conflict markers left in the code, OR commits that look like blind "ours"/"theirs" resolutions of conflicts the diff suggests should have merged content from both sides.

---

#### 7. Test Result Assertions

**Rule:** Prefer `assert_eq!(result, Ok(value))` over `assert!(result.is_ok())` because the former prints the actual error on failure. If the success value is uninteresting or the error type doesn't implement `PartialEq`, use `result.unwrap()` (which also prints the error). The same applies to error checks: prefer `assert_eq!(result, Err(specific))` or `result.unwrap_err()` over `assert!(result.is_err())`.

**Flag:**
- `assert!(result.is_ok())`, `assert!(result.is_err())`, `assert!(opt.is_some())`, `assert!(opt.is_none())` patterns in tests where the value or error would carry useful information.

---

#### 8. One Thing per Test

**Rule:** A test should focus on one observable behavior. Avoid doing many things in one test with a single assert at the end — when it fails, you don't know which step broke. Either split into focused tests, or keep a long test only when other tests cover each piece individually.

**Flag:**
- Tests with many setup steps and many actions that culminate in a single final assertion which doesn't pinpoint the failing step.
- Tests covering multiple unrelated behaviors under one `#[test]` function.

---

#### 9. Test Names Use `test_` Prefix

**Rule:** Functions marked `#[test]`, `#[tokio::test]`, `#[rstest]`, etc. should start with `test_`. Test names can be long and descriptive (e.g., `test_send_tx_with_duplicate_nonce_returns_already_received`).

**Flag:**
- Test functions whose names don't start with `test_`.

---

#### 10. Integration / Flow Test Placement

**Rule:** Unit tests should be < 1 second and deterministic unless there's a specific reason otherwise. Slow, integration, or flow tests belong under `tests/` at the crate root (where each test file runs in its own process, sequentially). If an integration test needs `#[cfg(test)]`-only features of the crate, use a dedicated integration-test crate rather than a feature flag.

**Flag:**
- Slow-looking unit tests in `src/` that perform real network I/O, real disk I/O, real timers, or otherwise look like they take seconds rather than milliseconds.
- Integration-style scenarios placed inside `src/` modules instead of under `tests/`.
- New `#[cfg(feature = "testing")]` gates intended to expose internals for integration tests when a separate integration-test crate would be cleaner.

---

#### 11. Binary Tests Refactor Logic Out

**Rule:** Don't test binaries by spawning them as executables. Refactor the binary's main logic into a library function and unit-test the function.

**Flag:**
- Tests that invoke `Command::new(env!("CARGO_BIN_EXE_..."))` or otherwise run the binary as a subprocess for behavioral testing.

---

#### 12. Dependency Injection via mockall

**Rule:** When a component depends on a service that's hard to instantiate in tests (database, network, time, file system), define a trait with `#[cfg_attr(test, mockall::automock)]` and inject through a generic parameter so tests can substitute a `MockX`.

**Flag:**
- Structs/functions that hardcode a concrete external dependency in a way that prevents unit testing.
- Tests that require setting up real external services because the production code doesn't expose a trait seam.

---

#### 13. No Sleep in Tests

**Rule:** Never use real sleeping in tests — it slows the suite and creates timing flakiness. Use `tokio::time::pause()` together with `tokio::time::advance()` to simulate elapsed time.

**Flag:**
- Any `std::thread::sleep`, `tokio::time::sleep`, `tokio::time::sleep_until`, `async_std::task::sleep`, etc. inside test bodies (anything under `#[cfg(test)]`, `#[test]`, `#[tokio::test]`).

**Don't flag** sleeps in integration tests under `tests/` that are explicitly testing real-async timing behavior — but still note them so the reviewer can decide.

---

#### 14. Panic Primitives — `panic!`, `todo!`, `unreachable!`, `unimplemented!`

**Rule:**
- `panic!` is for unrecoverable states (corrupt data, broken compile-time-guarantee invariants). Verify the panicking process actually halts the system (not auto-restarted in a loop).
- `todo!` marks code that will be filled in later.
- `unreachable!` is for paths that genuinely cannot execute.
- Never use `unimplemented!` — use `todo!` instead (they overlap, and we standardize on one).

**Flag:**
- Any `unimplemented!()` invocation.
- `panic!()` in code that runs inside a `loop {}` or under a supervisor that auto-restarts the process (since panicking won't actually stop the system there).
- `unreachable!()` on a branch that could plausibly execute (i.e., the invariant isn't actually airtight).

---

#### 15. Error Type Naming Ends with `Error`

**Rule:** Error structs and enums must have names ending with `Error` (e.g., `StorageError`, `ParseTransactionError`, `PeerNotAllowedError`). Bare `Storage` or `ParseTransaction` is wrong for an error type.

**Flag:**
- Types that derive `thiserror::Error` or implement `std::error::Error` whose name doesn't end in `Error`.
- Types appearing in `Result<_, T>` whose name doesn't end in `Error`.

---

#### 16. When to Return `Result`

**Rule:** Return a `Result` only when the caller is expected to handle the error. Don't propagate via `?` if you'll immediately `.unwrap()` at the call site — `panic!` at the source of the failure for a better stack trace and less boilerplate. Conversely, don't return a `Result` whose error is meant to be ignored — handle internally (e.g., log) and return a non-`Result` type.

**Flag:**
- Functions whose callers always `.unwrap()` or `.expect()` the result (suggests the function should panic at the source instead).
- Functions whose callers consistently use `let _ = ...` or `.ok()` to discard the result (suggests the function should swallow the error internally).

---

#### 17. `unreachable!` and `expect` Messages Explain *Why*

**Rule:** Messages for `expect(...)` (when used for "should never happen" cases) and `unreachable!(...)` are written for the code reader, not the program runner. They should state the invariant that makes the case impossible — *why* the error can't happen — not what went wrong. Bad: `.expect("failed to get IMPORTANT_PATH")`. Good: `.expect("IMPORTANT_PATH is set by wrapper_script.sh at startup")`.

**Flag:**
- `expect` / `unreachable!` messages that just describe the failure ("Failed to ...", "Couldn't ...", "Error in ...") without stating the invariant.

---

#### 18. Unnecessary Panics — Combine Check with the Panicking Operation

**Rule:** Don't write a guard immediately followed by code that panics if the guard wasn't there — combine them. Bad: `if v.is_empty() { return; } let x = v[0];`. Good: `let Some(x) = v.first() else { return; };`. Look for: emptiness check + indexing, `None` check + `.unwrap()`, key existence + map indexing.

**Flag:**
- `is_empty()` guard followed by `[0]`/`[i]` indexing.
- `is_some()` / `is_none()` guard followed by `.unwrap()`/`.expect()` on the same value.
- `contains_key()` guard followed by `[&key]` map indexing.

---

#### 19. Error Type Crate Selection and `PartialEq`

**Rule:** Library crates use `thiserror`. Binary crates use `anyhow`. Error enums should derive `PartialEq` whenever possible — without it, you can't `assert_eq!` on `Result<_, E>`.

**Flag:**
- Library code (a crate that's a library, not a binary) using `anyhow::Error` or `anyhow!` for its own returned errors.
- Binary code defining `thiserror`-style domain errors at the top level (where `anyhow` would suffice for app-level error reporting).
- Error enums whose variants are all `PartialEq`-compatible but the enum itself doesn't derive `PartialEq`.

---

#### 20. Error Message Format — Lowercase, No Punctuation

**Rule:** Error messages (especially `#[error("...")]` strings on `thiserror` enums) should be lowercase sentences without trailing punctuation. Nested errors usually string-interpolate inner messages, so consistent casing matters.

**Flag:**
- Error message strings starting with a capital letter (when not interpolating proper nouns/types).
- Error messages ending with `.`, `!`, or `?`.

**Don't flag** messages that interpolate identifiers, type names, paths, URLs, or similar tokens that legitimately retain their original casing.

---

#### 21. Prefer `expect` over `unwrap`; No Eager Work in `expect`

**Rule:** In non-test source code, prefer `.expect("reason this can't fail")` over `.unwrap()`. The `expect` argument is evaluated EAGERLY — never put non-const work (function calls, `format!`, allocations) inside it. Use `unwrap` only in tests or absolutely trivial, bulletproof scenarios.

**Flag:**
- `.unwrap()` in non-test source code.
- `.expect(format!(...))`, `.expect(some_function())`, `.expect(a_string_variable)` — anything that allocates or runs code on every call.

---

#### 22. Always Check Return Values; Split Mutating Action from Check

**Rule:** Always check return values from functions/methods, especially `Option`, `bool`, or status returns from collection mutators (`HashMap::insert`, `HashSet::insert`). When a mutating action returns a status, split the action and the check into two lines so the action is visible:
- Bad: `if map.insert(k, v) { handle_dup(); }` — the mutation is hidden inside the condition.
- Good: `let was_present = map.insert(k, v); if was_present { handle_dup(); }`.

**Flag:**
- Discarded return values from `insert`, `remove`, `replace`, `pop`, `swap_remove`, etc., on collections.
- Bool/Option-returning mutators called inside `if`/`while`/`match` conditions without an intermediate `let`.

---

#### 23. Getter Naming — No `get_` Prefix

**Rule:** A getter for the field `foo` should be `fn foo()`, not `fn get_foo()`. Same applies to non-field getters, except where `get_*` genuinely improves readability.

**Flag:**
- Methods named `get_<field>` that return a field of the same name (or a reference/copy of it).

---

#### 24. Types in Public API

**Rule:** Public API types — function parameters, return types, struct fields exposed to other crates — should prefer `std` types, primitives, or types defined within this crate. Using a 3rd-party type forces every consumer onto the same exact version of that 3rd-party crate (Cargo can't fetch multiple versions when types cross crate boundaries).

**Flag:**
- `pub` function signatures using non-std non-local types: e.g., `pub fn timestamp() -> chrono::DateTime<...>`, `pub fn id() -> uuid::Uuid` (when this crate didn't define `chrono`/`uuid` re-exports as part of its API).
- `pub struct` fields with such types.

**Don't flag** types this crate intentionally re-exports as part of its surface.

---

#### 25. Wide Parameter Types

**Rule:** Function parameters should be the most general type that satisfies the function's needs:
- `&[T]` over `Vec<T>` and `&Vec<T>`.
- `&str` over `String` and `&String`.
- `Option<&T>` over `&Option<T>` (callers holding `&Option<T>` can pass `.as_ref()`; the reverse is not possible).

**Flag:**
- Read-only function parameters typed `Vec<T>`, `&Vec<T>`, `String`, `&String`, `&Option<T>`.

---

#### 26. Unnamed Function Parameters at Call Sites

**Rule:** Avoid call sites with ambiguous bare values like `foo(true, false)` or `bar(None, 5)`. Use one of: per-parameter enums, a parameter struct, or named local variables at the call site (with the understanding that local variables aren't compiler-enforced when the API changes). Single-bool arguments are okay if the function name plus the value clearly conveys intent (e.g., `set_visible(true)`).

**Flag:**
- Function calls with multiple bool/`None`/`Some(...)` literal arguments where each value's meaning isn't obvious from the function name alone.

---

#### 27. Logging Coverage and Levels

**Rule:** Every piece of information that helps debug a flow or know system state should be logged. Levels:
- ERROR — unexpected condition needing immediate attention.
- WARN — potentially harmful situation the system can recover from.
- INFO — high-level events conveying state or confirming normal operation.
- DEBUG — detailed info useful for diagnosing in the environment; not so frequent it drowns out other debug logs.
- TRACE — too-frequent or verbose at higher levels; typically only enabled for targeted debugging.

**Flag:**
- Significant flow steps with no logging at all (e.g., a major state transition that emits no event).
- Logs at clearly wrong levels: `info!` for a per-message hot-path event firing thousands of times per second; `error!` for a routine validation failure; `warn!` for normal operation; `debug!` for something a user/operator must see.

---

#### 28. Log Titles in `ALL_CAPS` for Searchability

**Rule:** For logs that get frequently searched (errors, key state transitions, lifecycle events), prefix with an ALL_CAPS title — e.g., `info!("PROCESS_BLOCK: starting block {}", block_num)`. Once introduced, the title should not be changed (the rest of the message can be reworded), so the search term stays stable.

**Flag:**
- Load-bearing logs (errors, key state transitions, lifecycle events) that lack an ALL_CAPS prefix and would be hard to grep.
- Renamed ALL_CAPS titles in this diff (the title used to be `FOO_BAR` and is now `FOO_BAZ`) — these break log search history.

**Don't flag** trivial debug logs.

---

#### 29. Newtypes for Type Safety; No Type-Alias Pretenders

**Rule:** Frequently used primitive values (especially distinguishable concepts like `Nonce`, `Timestamp`, `BlockNumber`) should be wrapped in newtypes: `struct Nonce(u64);`. `type Foo = u64` aliases do NOT enforce anything — they compile interchangeably with the primitive — and should not be used for type safety.

**Flag:**
- Function signatures passing multiple `u64` / `u32` / `usize` / `bool` / `String` parameters where mixing them would compile but be semantically wrong.
- `type` aliases on primitive types used as if they were a new type (`type Nonce = u64`).

---

#### 30. Newtype Wrappers Implement `Deref` / `DerefMut`

**Rule:** Pass-through newtype wrappers (`pub struct Foo(pub u64);`) used through `.0` access should implement `Deref` (and `DerefMut` if mutable access is needed) so callers write `*foo > 0` instead of `foo.0 > 0` (and especially to avoid `foo.0.0.1` chains).

**Flag:**
- Any expression with `.0.0` or deeper nested-tuple-index access.
- `pub struct X(pub T);` with no `Deref` impl that's accessed through `.0` more than trivially.

---

#### 31. API Documentation Completeness

**Rule:** Every `pub` struct, enum, member, function, method, and enum variant should have a doc comment, unless its name fully conveys its meaning. Use `///` (not `//`) for documentation.

**Flag:**
- Undocumented `pub` items where the name doesn't make the meaning self-evident.
- Public enum variants without doc comments where the variant's purpose isn't obvious.

**Don't flag** trivially obvious items like `pub fn id(&self) -> Id` or a builder method that simply sets the field with the same name.

---

#### 32. Comment Style — `///` vs `//`, No `/* */`, Capitalization, Period, TODO Owner

**Rule:**
- Use `///` for API documentation (for the user).
- Use `//` for internal implementation comments (for someone reading the implementation).
- Never use `/* ... */` style comments.
- All comments — including inline — start with a capital letter and end with a period.
- TODO comments must include an owner: `// TODO(alice): ...`. If the owner isn't you, ensure they're aware.

**Flag:**
- Any `/* */` comment.
- Comments starting with a lowercase letter.
- Comments not ending with a period (or other terminal `.` / `!` / `?`).
- TODO comments without `(name)` after `TODO`.
- `///` used on private items (should be `//`); `//` used as documentation on `pub` items where `///` is appropriate.

---

#### 33. Abbreviations and Acronyms — Where They're Allowed

**Rule:**
- Abbreviations (`tx`, `cfg`, `ctx`, `idx`, `str`, `req`, `resp`) are allowed ONLY in variables, function arguments, struct fields, and function names. NOT in struct names, enum names, or documentation.
- Acronyms (e.g., `ABI`, `URL`, `CPU`) ARE allowed in struct/enum names and matching variables. If a struct/enum is an acronym, introduce/expand it in the doc comment of the type.

**Flag:**
- Struct/enum names containing abbreviations (e.g., `TxValidator`, `CfgParser`, `ReqHandler`).
- Abbreviations inside `///` doc comments (e.g., "...the tx is processed...").
- Acronym-named types whose `///` doc doesn't expand the acronym.

---

#### 34. Comment Quality — Add Information, Don't Restate Code

**Rule:** Comments should add information not trivially observable in the surrounding code. Bad: `// Add foo to collection` above `vec.push(foo);`. Good: comments that explain *why* a non-obvious choice was made, document an invariant, or summarize a paragraph of code (consider extracting such a paragraph into a named helper function so the function name documents it).

**Flag:**
- Comments that paraphrase the immediately following statement.
- Comments above trivial operations (`push`, `insert`, `return`, `clone`, increment) that just describe the operation.
- Excessive AI-comment-bloat: every line or every short block has a redundant comment.

---

#### 35. New External Dependencies and Unmaintained Crate Checks

**Rule:**
- Adding any new dependency requires manager approval. Even transitively-present crates count.
- Be conservative with helper crates; avoid single-use crates.
- Vetting checklist for new deps: last commit < 1 month ago; ~100+ stars (small crates) or ~1000+ (large); no "no longer maintained"/"archived" notices in README; recent issues/PRs receive maintainer attention; not superseded by `std` (`lazy_static`, `async_trait`).

**Flag:**
- Any new entry in `[dependencies]`, `[dev-dependencies]`, or `[build-dependencies]` of any `Cargo.toml`. Surface each one for the reviewer with a note that approval is required.
- Any usage in source code of crates known to be unmaintained or superseded by `std`.

---

#### 36. Avoid `join!` — Use `try_join!` or Other Short-Circuiting Alternatives

**Rule:** `futures::join!` and `tokio::join!` don't short-circuit on error — when one future fails, the others keep running, which can hide errors and waste work. Prefer `try_join!`, `tokio::try_join!`, or `JoinSet`/`FuturesUnordered`-based patterns.

**Flag:**
- Any `join!(...)` invocation (whether `futures::join!`, `tokio::join!`, or `tokio::macros::support::join!`).

---

#### 37. Avoid `select!` Unless Cancel-Safe

**Rule:** `select!` cancels the futures that don't win the race. Futures that aren't cancel-safe will leak partial state, drop important resources mid-operation, or deadlock. Prefer spawning tasks separately (`JoinHandle` is cancel-safe) or using `FuturesUnordered` / `JoinSet`.

**Flag:**
- Any `select!`/`tokio::select!` invocation. Examine each branch and explicitly note whether the future in that branch is cancel-safe (e.g., `tokio::sync::mpsc::Receiver::recv` is, but a custom future that drives a state machine across `.await` points often isn't). Flag any branch whose future isn't clearly cancel-safe.

---

#### 38. Task Handles Must Be Retained

**Rule:** When you `tokio::spawn` (or any equivalent), the returned `JoinHandle` must be kept and awaited (or joined) later — otherwise the task detaches from the process. If dropping the handle is intentional because completion is tracked via another channel (e.g., a `oneshot`), add a comment explaining why dropping is safe.

**Flag:**
- `tokio::spawn(...)` where the `JoinHandle` is dropped immediately, assigned to `_`, or used as the bare last expression of a function returning `()` without a comment explaining why detachment is safe.

---

#### 39. Manual `Future` Implementations Must Wake the Stored Waker

**Rule:** A manually implemented `Future` that returns `Poll::Pending` MUST store the `Waker` (via `cx.waker().clone()` or `cx.waker().wake_by_ref()` patterns) and call `wake()` later when the underlying state changes — otherwise the future hangs forever.

**Flag:**
- `impl Future for X` (or `impl Stream for X`) bodies that return `Poll::Pending` without storing the waker, OR store it but don't wake it from any state-transition path.

---

#### 40. Prefer `#[expect]` over `#[allow]`

**Rule:** Use `#[expect(...)]` instead of `#[allow(...)]` for lint suppression. `#[expect]` warns when the suppressed lint is no longer triggered, preventing silent stale suppressions.

**Flag:**
- Any `#[allow(...)]` attribute introduced or modified in the diff.

**Don't flag** cases where `#[allow]` is required by an external crate's expectations or by tooling that doesn't yet recognize `#[expect]`.

---

#### 41. Macros — Use Sparingly and Format Manually

**Rule:** Use macros only when non-macro alternatives are infeasible (true DSLs, repetitive boilerplate not solvable by generics or trait impls). The more expressive the macro, the less it can be reasoned about. Inside macro invocations (`stream!`, `indexmap!`, `vec!`, `quote!`), `rustfmt` doesn't format the body — verify the inner code is formatted manually.

**Flag:**
- New declarative or procedural macros where a generic function, trait, or simple helper would suffice.
- Test parameterization (`rstest`) with very complex types/values where a free helper function called from several one-line tests would be clearer.
- Code inside `stream!`, `indexmap!`, `quote!`, etc. that's clearly unformatted (inconsistent indentation, no spaces around operators, multi-statement blocks without breaks).

---

#### 42. Imports — `crate::` Not `super::`

**Rule:** All `use` statements must use `crate::` paths (or external crate names). Avoid `super::` in `use` statements — `crate::` paths can be copy-pasted between files unchanged, while `super::` paths break when the file moves.

**Flag:**
- Any `use super::...` statement in the diff.

---

#### 43. Prefer `let-else` or `match` over `if let { ... } else { ... }`

**Rule:** `if let Some(x) = foo { ... } else { ... }` should be rewritten as either:
- `match foo { Some(x) => ..., None => ... }` when both arms have substantive logic, OR
- `let Some(x) = foo else { return / continue / break ... };` for early-return short-circuits.
The `if let { } else { }` pattern carries more cognitive load and is always more concise as one of the alternatives.

**Flag:**
- Any `if let <pattern> = <expr> { ... } else { ... }` block in the diff. Recommend `match` or `let-else` based on whether the `else` branch short-circuits.

---

#### 44. American English Spelling

**Rule:** Use American English in identifiers, comments, log messages, and error messages: `serialize` (not `serialise`), `initialize` (not `initialise`), `canceled` (not `cancelled`), `behavior` (not `behaviour`), `color` (not `colour`), `optimize` (not `optimise`), `analyze` (not `analyse`), `center` (not `centre`). When a 3rd-party crate uses British English (e.g., libp2p `Dialling`), maintain that spelling when referring to its types/functions.

**Flag:**
- British English in any identifier, comment, log message, or error message (introduced in the diff): `serialise`, `serialised`, `initialise`, `initialised`, `cancelled`, `cancelling`, `behaviour`, `behaviours`, `colour`, `optimise`, `analyse`, `centre`, `licence` (as a verb), etc.

**Don't flag** spellings that clearly originate from a 3rd-party API (e.g., `Dialling` when used as part of a libp2p type name).

---

#### 45. Use `Self` in `impl` Blocks

**Rule:** Inside `impl Foo` blocks, prefer `Self` to repeating the concrete type name `Foo`. Applies to constructors (`fn new() -> Self`), associated functions, type bounds, struct literal expressions (`Self { ... }`).

**Flag:**
- Inside an `impl Foo` block: any `Foo` that could be `Self` — return type `-> Foo`, struct expression `Foo { ... }`, type bound `T: Bound<Foo>`, etc.

---

#### 46. Associated Functions Should Depend on `Self`

**Rule:** A function defined inside `impl Foo` that doesn't use `Self`, `self`, or any of `Foo`'s generic parameters doesn't belong there — it should be a free function.

**Flag:**
- Associated functions inside `impl` blocks that never reference `Self`, `self`, or `Foo`'s generics.

---

#### 47. Casting — `into`/`try_into` or `from`/`try_from`, Never `as`

**Rule:**
- Use `value.into()` / `value.try_into()?` when the target type is determined by context.
- Use `Target::from(value)` / `Target::try_from(value)?` when the target needs to be specified.
- Do NOT use `as` casts for numeric conversion — `as` saturates silently on overflow/underflow, hiding bugs. The team's lint bans `as` in this repo.

**Flag:**
- Any `as` cast in the diff (e.g., `x as u64`, `n as i32`, `len as f64`).

**Don't flag** `as` for raw pointer or function-pointer casts where no safe alternative exists.

---

#### 48. Eager vs Lazy `_or` Methods

**Rule:** Methods ending in `_or` (e.g., `unwrap_or`, `ok_or`, `map_or`, `expect`) evaluate their argument EAGERLY — even when the original value is `Some`/`Ok`. Use the `_or_else` siblings (`unwrap_or_else`, `ok_or_else`, `map_or_else`) for lazy evaluation. The same applies to any method that takes a non-closure argument in a position where the argument might not be needed.

**Flag:**
- `.unwrap_or(<non-trivial expression>)`, `.ok_or(<non-trivial expression>)`, `.map_or(<non-trivial expression>, ...)`, `.expect(<non-const expression>)` — anything that allocates, calls a function, or otherwise does non-trivial work eagerly.

**Don't flag** literal/const arguments like `.unwrap_or(0)`, `.unwrap_or("")`, `.unwrap_or_default()`.

---

#### 49. HashMap/HashSet Iteration Is Non-Deterministic

**Rule:** Don't iterate `HashMap` or `HashSet` — iteration order is non-deterministic in Rust. Use `BTreeMap`/`BTreeSet` (preferred) or `IndexMap`/`IndexSet` (when insertion order matters or hash-based lookups dominate). Prefer `BTree*` over `Index*` because `Index*` has O(n) removal (it's `Vec`-backed).

**Flag:**
- `for ... in hash_map.iter()`, `.values()`, `.keys()`, `.into_iter()` over a `HashMap`/`HashSet`.
- `.collect::<Vec<_>>()` from a `HashMap`/`HashSet` iteration.
- `HashMap`/`HashSet` declarations where the order of subsequent iteration matters for behavior or output.

---

#### 50. Use `Vec::with_capacity` When Size Is Known

**Rule:** When the eventual size of a `Vec` (or `String`, `HashMap`, etc.) is known up front, use `Vec::with_capacity(n)` to avoid reallocations during pushing.

**Flag:**
- `let mut v = Vec::new();` (or `let mut v = vec![];`) followed by a loop with a known length pushing onto `v` (especially when the loop iterates over a slice/iterator with a known size hint).
- Same pattern with `String::new()` + `.push_str()` in a loop, or `HashMap::new()` + `.insert()` with known cardinality.

---

#### 51. No `ref` Keyword in Patterns

**Rule:** The `ref` keyword in patterns is legacy. All uses can be replaced more concisely with `&` on the right-hand side: `if let Some(n) = &maybe_name` instead of `if let Some(ref n) = maybe_name`.

**Flag:**
- Any `ref` or `ref mut` keyword in patterns (`match`, `if let`, `let`, function parameters).

---

## Output

Group findings by file path (relative to the repo root). Sort findings within each file by line number.

```markdown
## Codestyle Review

### <file path>
- **L<line>** — `[<rule number>. <short name>]` <violation>
  - Fix: <suggested fix>
- **L<line>** — `[<rule number>. <short name>]` <violation>
  - Fix: <suggested fix>

### <next file path>
- ...

## Summary

| Rule | Findings |
|------|----------|
| <rule number>. <name> | <count> |
| ... | ... |

**Total: N findings across M files. K rules triggered.**
```

If zero findings overall:

```
Codestyle review: clean. No violations found across 51 rules.
```

### Notes

- Many rules cover subjective territory (logging coverage, comment quality, "one thing per test"). Treat findings from those as discussion starters — let the user decide which to act on rather than auto-fixing.
- Several checks catch things that are also caught by clippy or rustfmt (e.g., `as` casts via `clippy::as_conversions`). The codestyle review is independent — flag the violation regardless of whether a lint also catches it. The reviewer can choose which findings need a code change versus just enabling a lint.
- This review only checks the Rust Coding Conventions document. It does not run clippy, tests, or other validation — pair with `/validate` for those.
