---
name: shahak-review
description: Review code changes through the lens of Shahak Shama's review preferences. Use when preparing code for Shahak's review, or to self-review before submitting a PR.
argument-hint: [file-or-branch]
---

Review the code changes specified by $ARGUMENTS (defaults to staged/unstaged changes if not provided) against Shahak Shama's review preferences below. For each violation found, output:

1. **File and line**
2. **Rule violated** (reference the section)
3. **What Shahak would say** (concise, direct)
4. **Suggested fix**

Group findings by file. At the end, summarize the total count per category.

---

# Shahak Shama's Code Review Preferences

Comprehensive rules distilled from all PR review comments on Andrew's PRs.

---

## 1. Naming

### Be specific, not generic
- Names must answer "what is this?" without surrounding context. Generic names like `cooldown_seconds` should be `new_connection_stabilization_seconds`. `target_peers` in a whitelist context should be `allowed_peers` or `whitelist`.
- Disambiguate counts: `num_shards` is confusing — use `num_total_shards` or `num_message_shards`.
- Variable names for collections of connections should be `connections_tracker` (plural), not `connection_tracker`.

### Names should reflect the full semantic meaning
- If a set contains both "peers we're dialing" and "peers already connected", don't call it `dialing_peers`.
- If a function does more than assert (e.g., it also runs swarms), name it `run_with_expectations` not `assert_deliveries`.
- If a function polls for close-connection events, call it `expect_close_connection_event`, not `poll_close_connection`.
- If a function collects events AND asserts no other events exist, the name should reflect both: `expect_all_events_are_close_connections`.

### Error types end with `Error`
- `PeerNotAllowed` should be `PeerNotAllowedError`.

### Booleans should use past tense for state
- `broadcast_my_shard` (did it happen?) should be `did_broadcast_my_shard` or `broadcasted_my_shard`.

### Prefer American English
- `Dialling` -> `Dialing`. Use American English consistently (unless constrained by external libraries like libp2p).

### No abbreviations for variables
- `pid` -> `peer_id`, `tx`/`rx` -> `message_tx`/`message_rx` (when the channel carries messages).

### Constants should match variable naming conventions
- `COMMITTEE` -> `COMMITTEE_ID` if the type is `CommitteeId`.

### Prefer newtypes over type aliases
- `type NodeIndex = usize` -> `struct NodeIndex(pub usize)` for stronger type safety.

### Use domain-appropriate names
- Names should match the domain context: `target_peers` makes sense in Kademlia (targeting discovery) but not in access control (where `allowed_peers` / `whitelist` is correct).

### Function names should describe behavior, not implementation
- `validate_on_rayon` should capture what you're getting (e.g., `validate_blocking`), not the tool used.
- `BroadcastUnit` -> `SendUnitToPeers` when sending to a specific set of peers.

### Test-only code should be obvious
- Add `for_test` or similar markers to test-only infrastructure names.

### Prefix channel variables with their purpose
- Bare `tx`/`rx` -> `engine_tx`/`engine_rx`, `response_tx`/`response_rx`, `message_tx`/`message_rx` depending on what flows through the channel.

### Extract tuples into named structs
- `HashMap<(Channel, PeerId, MessageRoot), ...>` -> extract the triplet key into a named struct like `MessageKey`.

### Use `collect` over manual loops for building collections
- `for (peer, _) in ... { broadcast_list.push(peer); }` -> use `.collect()` with iterator adapters.

### Function parameter order: most important first
- Put `message` before `channel`, `publisher`, `keypair`. Order by conceptual importance to the caller.

---

## 2. Documentation & Comments

### Document public structs and functions
- Every public struct needs documentation. "Documentation!" is a valid review comment.

### Comments should describe the high-level "what", not low-level "how"
- Test comments should start with a high-level description of the step, then optionally add lower-level details.
- `// Poll -- RequestDial is intercepted by Stream impl and forwarded to DialingBehaviour` is too low-level as a primary comment. Lead with the high-level intent.

### Simplify comment language
- "with backoff" -> "after some time" in user-facing comments. Don't leak implementation details into behavioral descriptions.
- "Manages dialing to peers with exponential backoff" -> "Manages dialing to peers with retries".

### Name unused variables descriptively
- `_` is insufficient; use `_addresses` so the reader knows what is being intentionally ignored and why it's ok.

### Comments should apply to entire code paragraphs
- Remove blank lines between a comment and the code it describes if they belong to the same logical block.

### Document invariants that aren't obvious from the code
- If a condition is always true due to prior validation but the code checks it defensively, add a comment explaining why.
- "All units passed validation so they all have the same signature" deserves a comment.
- "When we construct we broadcast our shard, so if we now receive it we shouldn't count it" needs a comment.

### Document failure behavior
- "Can this request fail in any way? If no, comment about it."

### TODOs should use "consider" for open-ended discussion
- If the goal of a TODO is to have a future conversation rather than a definite action, prefix with "consider": `// TODO: consider parallelizing shard processing`.

### Add comments before panic-on-failure blocks
- Before printing debug info and panicking: `// Test failed. Printing information before panicking`.

### No visual separator comments
- Don't use `// --- Reconstruction ---` or `// =========` decorative comment lines.

### Don't over-document trivial things
- Remove doc comments that merely restate the type signature or field name. Focus documentation on non-obvious semantics.

### Explain "why" for non-obvious code choices
- If using rayon instead of tokio for blocking work, explain why in a comment.
- If dropping a task handle is safe because a oneshot channel tracks completion, say so.

### Summarize discussion outcomes in comments
- When a PR discussion reaches a conclusion, write a summarized version as a code comment so future readers don't need to read the PR thread.

### Remove comments that just say "Done" was applied
- TODOs that are completed should be removed, not left as markers.

---

## 3. Code Organization

### Public API / tests first, helpers last
- In test files: put test functions at the top, helper functions at the bottom.
- Readers should encounter the high-level flow first.

### Use `use` imports, not inline qualified paths
- `futures::channel::mpsc::UnboundedSender<PeerId>` in a struct field -> import at the top of the module.
- `tokio::sync::mpsc::unbounded_channel::<(PeerId, PeerId)>()` -> import at the top.

### Gate test-only visibility with `cfg(any(test, feature = "testing"))`
- Don't make internal modules unconditionally `pub` just for integration tests. Use feature gating.

### Extract magic numbers to named constants
- `ActiveCommittees::new(3)` -> define `const DEFAULT_ACTIVE_COMMITTEES_CAPACITY: usize = 3;` at the top of the file.
- Small durations used for "just past the deadline" -> `EPSILON_DURATION`.

### Don't create trivial wrapper functions
- If a function is 1-2 lines and only called once or twice, inline it. `create_sleeper(delay)` that just calls `Box::pin(tokio::time::sleep(delay))` doesn't need to exist.

### Extract complex logic into structs with methods
- Connection tracking logic that manages a HashMap of peer connections should be a struct with `new`, `add_connection`, `print_progress`, `run_until_full_mesh` methods.

### Extract async tasks into named functions
- `tokio::spawn(async move { ... })` with non-trivial logic should be extracted to a named function.

### Don't leave unnecessary `pub` — use `#[allow(dead_code)]` instead
- If a function isn't used yet because later PRs consume it, mark it `#[allow(dead_code)]` rather than making it `pub`.

### Compute derived constants, don't duplicate
- `THREE_QUARTER_TTL` should be `TTL * 3 / 4`, not a separate hardcoded `Duration::from_millis(75)`.

---

## 4. API Design

### Enforcement should always be active
- Don't add "opt-in enforcement" flags. If a whitelist behavior exists, it should deny by default. Pass an initial allowed set in the constructor rather than having a separate "activate" step.

### Minimize redundant state
- If you can compute disconnections from the set difference between previous and current allowed peers, don't maintain a separate `connected_peer_ids` set.
- If `None` just means a default value, use a plain type instead of `Option`.

### Unite overlapping sets in the caller
- Don't maintain separate `bootstrap_peer_ids` and `target_peers` in a whitelist behavior. Have the caller (NetworkManager) pass the union.

### Prefer channel-based APIs over public mutation methods
- `add_epoch` should be private; the constructor should return a channel sender for adding epochs.

### Use early returns
- Prefer `let ... else { return }` or early `if` guards over deeply nested `if let Some(first) = ... { ... }`.

### Use idiomatic Rust combinators
- Use `get_or_insert_with` instead of manually checking `if None` then setting.
- Use `drain` instead of iterate-and-remove patterns.

### Function should do one thing
- A function that does completely different things depending on state should be split, or the branching logic should move into the state type itself.
- Consider state machines that return action enums: `AddUnitOutput::NoOp | BroadcastUnit(unit) | EmitMessage(message)`.

### Avoid booleans in APIs; use enums
- `record_shard(is_my_shard: bool)` -> either rename to make the boolean obvious, or use `enum ShardOwner { Me, SomeoneElse }`.

### Check for existing types before creating new ones
- Before creating `struct CommitteeId(pub [u8; 32])`, check if the hash function or merkle tree already defines a suitable type.

### Use `let ... else` to avoid panicking indexing
- Instead of `if units.is_empty() { return Err(...) }` then `units[0]`, use `let Some(first) = units.first() else { return Err(...) }`.

### Use named structs instead of tuples for return types
- `(ValidationResult, Validator, PropellerUnit)` -> define `struct ValidationOutput { result, validator, unit }`.

### Use `expect` over `unwrap` in source code — and explain why it's safe
- Never `unwrap()` in non-test source code. Use `expect("reason this can't fail")`.
- The expect message should state why the invariant holds, not just what went wrong.

### Use `NonZeroUsize` for divisors
- If a parameter must be > 0, encode that in the type: `divisor: NonZeroUsize` instead of `divisor: usize`.

### Use `try_from` instead of `try_into` for clarity
- `u64::try_from(index)` is clearer than `index.try_into()` because the target type is explicit.

### Prefer `tokio::timeout` over `select! { sleep => ..., recv => ... }`
- When you have a single future with a deadline, use `tokio::timeout` instead of a manual `select!` with `sleep_until`.

### Use `unwrap_or(pending())` for optional futures in select
- Instead of `if is_some { unwrap().await }`, use `unwrap_or(std::future::pending())`.

### Don't leave detached tasks
- Convention: always store task handles. If dropping is safe because a oneshot channel tracks completion, add a comment explaining why.

### Reject resource exhaustion gracefully, don't panic
- When no slots are available for a new substream, reject gracefully (close or return error) rather than panicking.

---

## 5. Testing

### Test edge cases explicitly
- "Add unit test that the behaviour ignores dial failures from other connection ids."
- "Test multiple shards." "Test multiple messages and multiple broadcasters."
- "What happens if bootstrap peer is in the target set and then it's removed?"

### Eliminate redundant test parameterization
- "Why not just have the highest? What does 3 teach you that 10 doesn't?"
- Avoid cartesian product explosion: "All these cartesian products will cause for a large test time. Do only what's necessary (and try to put comments describing why it's necessary, what's special about the values)."
- Be conscious of test duration: "What's the length of these tests?"

### Use `unwrap()` over `assert!(result.is_ok())` in tests
- `unwrap()` displays the full error message on failure; `assert!(result.is_ok())` only shows `false`.

### Don't sleep in unit tests
- Use `now_or_never` (call it multiple times if needed to drain pending events) instead of `tokio::time::timeout` with a sleep.
- Exception: integration tests (in `tests/` folder) may sleep since they test real async behavior.

### A small CI-friendly version should exist alongside large ignored tests
- If you have a 100-node test that's `#[ignore]`, add a 5-node version that runs in CI.

### Extract function arguments into variables when meaning is unclear
- `create_network_manager(swarm, None, false)` -> extract `None` and `false` into named variables.

### Use `unwrap_err()` over `assert!(matches!(result, Err(...)))`
- `unwrap_err()` is more concise and shows the Ok value on failure.

### Use `unwrap()` freely in tests — skip `.expect("Failed to ...")`
- In tests, `.expect("Failed to prepare units")` doesn't add value over `.unwrap()` — the panic trace already shows the location.

### Use seeded randomness in tests
- Use seeded keypair/peer ID utilities for deterministic tests. Add TODO if seeded random isn't yet available.

### Add regression/snapshot tests for cryptographic code
- Merkle trees, hashing, encoding should have regression tests to catch accidental changes.

### Add static assertions for test preconditions
- If a test is interesting because `message_len % num_shards != 0`, assert that precondition explicitly so refactors don't silently make the test trivial.

### Explain what each test case uniquely covers
- If two test cases look similar (e.g., `claims 100, has 5` vs `claims 10, has 9`), add a comment explaining why both are needed. If the explanation is unconvincing, remove one.

---

## 6. PR Process & Commit Hygiene

### PR title and commit message must accurately reflect the change
- "Please change commit and PR title to reflect what this PR does. I prefer reviewing only after you do that."

### Commit body must carry a conversation summary
- The commit's first line is the `scope: subject` title; the **body** must end with a three-section summary of the Claude conversation that produced the PR: `## Goal`, `## Summary of changes`, and `## Key decision points` (for each non-trivial decision: what was decided, why, which alternatives were considered, and why they were rejected).
- Shahak reviews the *why* and the paths not taken, not just the diff — the rejected alternatives are otherwise lost when the chat ends. `/commit-summary` drafts this body. Include it even on small PRs (decision-points can be brief). This is Shahak's personal preference, not a repo-wide policy.

### Don't rename files mid-review
- "This PR is hard to review because you renamed the test file mid-review. Revert the rename and open a separate PR that merely renames the test file."

### Separate infrastructure from usage
- Test harnesses, helpers, and framework code should ideally be in a separate PR from the tests that use them.

### Rename consistently across the entire PR
- If you rename `set_target_peers` to `set_allowed_peers`, rename all test names, variable names, and comments that reference the old name.

### Delete dead code entirely
- Don't keep config flags or code paths for removed features. "Why not just delete it entirely?"

### Use TODOs to track cross-PR work
- "Add TODO to unite with sqmr tests into a test util file."
- "In a future PR, clean connected peers on disconnect event."

### Don't defer TODOs that are quick to fix
- "TODOs tend to be forgotten." If something takes 5 seconds (e.g., removing `pub` and adding `#[allow(dead_code)]`), just do it now.

### Question unnecessary dependencies
- If a dependency like `rand` with `std_rng` is added to Cargo.toml, ask "Why?" — justify new dependencies.

---

## 7. Async & Concurrency Patterns

### Store wakers and wake explicitly
- When a behaviour needs to be re-polled after an external event (e.g., `set_target_peers`), store the waker and call `wake()` when the event arrives.

### Prefer `sleep_until` with stored timestamps over stored futures
- Instead of storing a `Pin<Box<Sleep>>`, store `next_dial_time` and create a new `sleep_until` future each poll. This avoids subtle bugs with future reuse.

### Document when waking is NOT needed
- If a cancel operation can't produce new events, add a comment: "No wake needed because no event can be emitted here."

### Don't use oneshot channels when you can return directly
- If spawning blocking work on rayon, return the result from the closure and await the spawn handle directly instead of creating a oneshot channel.

### Use `FuturesUnordered` for multiple pending async tasks
- Instead of `Option<oneshot::Receiver<...>>` for a single pending validation, use `FuturesUnordered` to process multiple concurrently.

### Explain `select!` guard syntax in comments
- `Some(x) = rx.recv(), if condition =>` is non-obvious syntax. Add a comment explaining what happens when the guard is false (the branch is disabled, not that the item is discarded).

---

## 8. Design Philosophy

### Connection handling should be defensive
- Deny both inbound AND outbound connections to non-whitelisted peers.
- Implement access control at the earliest stage (`handle_pending_connection`, not `handle_established_connection`).

### Don't clear valid in-progress work on state changes
- When target peers change, don't clear pending queries — there could be valid queries there. Use the whitelist to filter instead.

### Process all items per heartbeat, not one per poll
- "You should dial all of them every heartbeat, not once per epoch."

### Consider what happens when state is simpler
- "What happens in libp2p if you request a disconnection when you're not connected? If nothing, then do this change" (i.e., simplify by removing guards for no-ops).

### Use appropriate log levels
- `warn` for things that indicate a bug or need oncall attention (e.g., protocol negotiation failure).
- `debug` for operational events useful during development (e.g., new message processor spawned, unregistered channel shard dropped).
- `trace` is fine for high-frequency per-shard events.
- Error events visible to users (Events enum) should only contain things the user/application cares about — internal failures should be internal events or logs.

### Use `chunks()` over manual index iteration
- `for i in (0..vec.len()).step_by(2)` -> `for chunk in vec.chunks(2)`.
- Use `.first().expect(...)` and `.last().expect(...)` on chunks instead of raw indexing.

### Eliminate redundant special cases
- If a loop handles the 1-element case correctly, don't add a separate `if len == 1` branch.

### Use consistent terminology across the codebase
- Pick one term for an action (emitted? finalized? received?) and use it everywhere. Don't mix terminology for the same concept.

### Protocol versioning should reflect maturity
- Use `0.x.0` for beta/experimental protocols, not `1.0.0`.
