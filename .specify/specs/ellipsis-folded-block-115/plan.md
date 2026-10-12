# Plan: ellipsis-folded-block

**Input**: `spec.md`, `research.md`, `data-model.md`, `contracts/folded-line-ellipsis.md`
**Branch**: `spec/ellipsis-folded-block-115` in worktree `/Users/arrrrny/Developer/zuraffa_115`

## Technical context

Single Flutter package, `zuraffa_code_editor` (renamed from
`flutter_code_editor`). Tests are raw `flutter test` — the repo's TDD profile is
`.specify/memory/tdd-profile.md`, and there is no test framework beyond
`flutter_test`. The coverage gate is a hard 100% of lines, enforced by
`tool/coverage_gate.py` and by the pool's CI.

Target platform is the same as the package's: Flutter stable, macOS host. There
is no platform-specific code in the change — the marker is a `TextSpan` leaf, so
it renders on every platform `TextPainter` does.

## Constitution check

| Principle | Status |
|---|---|
| Spec-first, then tests RED, then implementation | `tasks.md` orders every test before its implementation tasks |
| 100% line coverage, no exemptions without a written reason | Gate task is blocking; every new branch has a named test, including the reachable null from `cutLineIndexIfVisible` |
| No merge by the agent | The task ends at "open the PR and requeue the pool" |
| One PR at a time | Gated on #116 being merged first |
| Default behaviour unchanged unless the issue asks for it | With nothing folded the span tree is byte-for-byte identical; the three existing `span_builder_test.dart` examples pass unmodified |
| `--concurrency=2` on every test run | Stated in `tasks.md` Notes and in every command |

`.specify/memory/constitution.md` in this worktree is still the unfilled
Spec-Kit template, so there is no ratified clause text to cite beyond the
principles above; they are taken from the repo's enforced gates and from AGENTS.md
rather than from a document that says anything yet. Recording that here so the
reviewer is not sent looking for it.

## Project structure

One file changes under `lib/`. Nothing new is created there.

```text
lib/src/code_field/span_builder.dart        # the kept-line derivation and the splice
lib/src/code_field/code_controller.dart     # thread withFoldEllipsis through _createTextSpan
test/src/code_field/fold_ellipsis_test.dart # new, controller/widget level
test/src/code_field/span_builder_test.dart  # existing, extended with folded examples
test/src/code_field/search_result_highlighted_builder_null_style_test.dart # existing, must pass unmodified
test/src/folding/folded_closing_line_test.dart       # existing, must pass unmodified
test/src/folding/folded_block_keeps_next_block_start_test.dart # existing, must pass unmodified
```

`span_builder_test.dart` is extended by adding entries to its `_examples` map
(`:30-230`), which is the file's own convention: one `_Example` per shape, whole
tree asserted. That is the right place for the span-tree assertions, and it means
the "nothing folded ⇒ nothing changed" requirement is enforced by the three
examples that are already there rather than by a new test.

## Phase 0 — the derivation

Nothing to build beyond the set itself. `cutLineIndexIfVisible`
(`hidden_line_ranges.dart:65`) and `recoverLineIndex` (`:69`) are the whole
bridge between the full and visible line spaces, `foldedBlocks` is a public
`Set<FoldableBlock>` (`code.dart:36`) and `FoldableBlock.firstLine`
(`foldable_block.dart:9`) is public. No new helper, no new API, no change to any
of them.

## Phase 1 — the splice in `SpanBuilder`

Three changes to `lib/src/code_field/span_builder.dart`, all local to `build` and
`_buildNode`, plus one line in `CodeController`:

1. **Derive the kept lines once**, at the top of `build()` (`span_builder.dart:59`),
   beside the existing `_visibleLineIndex = 0` reset at `:60`: for each entry in
   `code.foldedBlocks`, take
   `code.hiddenLineRanges.cutLineIndexIfVisible(block.firstLine)` and keep the
   non-null values in a `Set<int>` (`:190-203`). The null case is reachable — a
   block nested inside an already-folded one — and dropping it there is what
   keeps the splice itself branch-free.

2. **Splice at the terminating node.** In `_buildNode` (`span_builder.dart:110-132`)
   the value of `_visibleLineIndex` at entry is the visible line the node starts
   on, because `_updateLineIndex` runs at `:118`, after `_paleIfRequired` at
   `:116`. A node whose own `value` ends with `'\n'` terminates the line *before*
   the counter's new position, so the test is `_foldedKeptLines.contains(
   _visibleLineIndex - 1)` (`:157`). The marker is then inserted in front of the
   run of newlines the value ends with, with the node's existing `children`
   rebuilt behind it (`:169-179`) — not appended after them, because a
   terminating node may have children of its own (`node.dart:62-67`) and those
   children already belong to the following line.

3. **The final-line-without-a-newline case.** `MyNode.splitLines`
   (`node.dart:55-70`) leaves the last piece without a trailing newline, so the
   tree can end mid-line. `_updateLineIndex` records that
   (`span_builder.dart:135-138`) and `build()` appends the marker to the end of
   the whole walk when the last visible line is a kept one (`:70-87`).

4. **Suppress the marker during a search.** `CodeController.buildTextSpan`
   (`code_controller.dart:1358-1361`) builds the tree with
   `withFoldEllipsis: visibleSearchResult.matches.isEmpty`, threaded through
   `_createTextSpan`'s new parameter (`:1374-1391`). Without this, every match
   following a folded line is sliced off the wrong text — see
   `contracts/folded-line-ellipsis.md` §Search-match path.

Nothing else in the class changes — the theme lookup, the pale handling, the
clamp, the `TextSpan` construction and its argument order all stay exactly as
they are.

## Phase 2 — the final-line-without-a-newline case

Covered by change 3 above, and kept as its own task because it is a separate
branch and therefore a separate coverage-gate obligation. It is guarded so that
it is inert unless the last visible line is a kept line — which is exactly the
comment-block-folded-to-its-first-line shape.

## Phase 3 — verification

Per the repo's gates:

1. `flutter test --concurrency=2` — full suite.
2. `dart analyze --fatal-infos`.
3. `dart format --output=none --set-exit-if-changed .`.
4. The CI-identical coverage gate from `quickstart.md` §3, which must read
   `100.00% >= 100.00% — OK`.

## Risks

| Risk | Mitigation |
|---|---|
| The marker lands mid-line instead of at the line's end | The splice is on the node that *terminates* the line, judged by its own value ending in `'\n'`. `splitLines` (`node.dart:55-70`) guarantees one such node per visible line, and the whole-tree assertions in `span_builder_test.dart` make a misplacement a diff, not a judgement call. |
| The marker leaks into the buffer | FR-3's test asserts `controller.text` byte-for-byte across fold and unfold; the implementation has no path to `visibleText` at all, since it only builds a `TextSpan`. A mutant that writes to the text cannot pass it. |
| A branch is unreachable and the 100% gate fails | The three branches are the kept-line-and-terminating-node case, the final-line-no-newline case and the null-from-`cutLineIndexIfVisible` case. All three have named tests and real fixtures (the #213 double fold for the null). If a branch still proves dead, it goes to `EXEMPT_LINES` with a written reason, renumbered by line. |
| The search-match path drops or duplicates the marker | `search_result_highlighted_builder.dart:92-110` was read rather than assumed, and the search test asserts the marker is present as one leaf with its own style, not split. |
| The marker is invisible because the base style has no colour | The fallback is the terminating node's resolved style, which is always non-null on a rendered line. A theme with no styles set still renders a glyph. |
| A reviewer expects configurability | `spec.md` Decisions records it as an explicit non-goal with the reason, so it reads as a decision rather than an omission. |
| The three existing `span_builder_test.dart` examples drift | They are run before and after. A change in the unfolded tree is a defect in this change, not a stale test. |

## Complexity budget

Two files under `lib/`, one private `Set<int>`, one private `bool`, one private
constant, one `TextSpan` spliced in front of the terminating node's newline run,
one guarded append for the final line, one internal flag threaded through
`_createTextSpan`, two test files. No new widgets, no new public types, no new
exports, no new listeners, no change to the folding machinery, the gutter, the
search builder or the widget tree.
