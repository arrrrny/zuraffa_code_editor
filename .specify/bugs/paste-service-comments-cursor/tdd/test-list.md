# TDD test list: paste-service-comments-cursor

Derived from `spec.md`.

| # | Test | Requirement | Red on master? |
|---|------|-------------|----------------|
| 1 | caret lands at the end of the pasted run | 1 | **yes** — 60 vs 92 |
| 2 | caret lands after the pasted run when it is inserted mid-text | 1 (no hidden range) | no (guard) |
| 3 | the pasted text reaches fullText in full | 4 | no (guard) |

Requirements 2, 3 and 5 are pinned by **existing** tests, listed here so the
coverage claim is auditable:

| Requirement | Pinned by |
|---|---|
| 2 — non-collapsed replacement collapses to the start of newly hidden text | `test/src/code_field/code_controller_hidden_ranges_test.dart` "A typed-in service comment becomes a hidden range" |
| 2 — same, folding variant | `test/src/code_field/code_controller_folding_editing_test.dart` "When deleting 2nd identical folded block, 1st one incorrectly folds" |
| 3 — unfolded block recovers the caret | `code_controller_folding_editing_test.dart` "Deleting folded comments", "Inserting after folded comments", "Unfolding" |

The guards (tests 2 and 3) run against master during the RED step to prove they
are not vacuous: both are green on master, so a regression in the fix would show
up as a new failure rather than as a silently passing test.
