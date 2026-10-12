# Plan: highlight-cursor-line

**Input**: `spec.md`, `research.md`, `data-model.md`, `contracts/current-line-highlight.md`
**Branch**: `spec/highlight-cursor-line-113` in worktree `/Users/arrrrny/Developer/zuraffa_113`

## Technical context

Single Flutter package, `zuraffa_code_editor` (renamed from
`flutter_code_editor`). Tests are raw `flutter test` — the repo's TDD profile is
`.specify/memory/tdd-profile.md`, and there is no test framework beyond
`flutter_test`. The coverage gate is a hard 100% of lines, enforced by
`tool/coverage_gate.py` and by the pool's CI.

Target platform is the same as the package's: Flutter stable, macOS host.

## Constitution check

| Principle | Status |
|---|---|
| Spec-first, then tests RED, then implementation | `tasks.md` orders every test before its implementation |
| 100% line coverage, no exemptions without a written reason | Gate task is blocking; every new branch has a named test |
| No merge by the agent | The task ends at "open the PR and requeue the pool" |
| One PR at a time | Gated on #87 being merged first |
| Default behaviour unchanged unless the issue asks for it | Null default keeps the tree identical; #86's invariant test passes unmodified |
| `--concurrency=2` on every test run | Stated in `tasks.md` Notes and in every command |

## Project structure

Single package; nothing new is created under `lib/` except what already exists.

```text
lib/src/code_field/code_controller.dart   # + currentLineColor, corrected doc example
lib/src/code_field/line_background.dart   # caret-line resolution + composition
lib/src/code_field/code_field.dart        # wider gate, one condition
test/src/code_field/current_line_highlight_test.dart   # new
test/src/code_field/per_line_background_test.dart       # existing, must pass unmodified
```

## Phase 0 — the conversion helper

Nothing to build. `CodeLines.characterIndexToLineIndex` already exists and is
already what `Code` uses for `CodeLineRange` (`code.dart:382-383`). No new
helper, no new public API.

## Phase 1 — the field and the layer

**`CodeController.currentLineColor`.** A plain `final Color?` field beside
`lineBackgroundBuilder`, with a doc comment that states: what it tints (the whole
row of the caret's line), which offset defines the caret (`extent`, and why), and
that it composes with `lineBackgroundBuilder` with the builder winning. See
`contracts/current-line-highlight.md`.

**`LineBackgroundLayer`.** Two changes, both local to `build`:

1. Compute `currentLineIndex` once, behind the guard from
   `research.md` R4.
2. Change the colour resolution at `line_background.dart:55` from
   `builder(visibleLines[row])` to the `??` chain from the contract.

Nothing else in the layer changes — the `Padding`, the `Column`, the
`SizedBox`-for-untinted, the `Container`-for-tinted, and the `@internal`
annotation all stay exactly as #86 left them.

**`CodeField`.** The gate at `code_field.dart:652-653` becomes a conjunction. No
new `Stack`, no new scroll controller, no change to `_visibleRowHeights`.

## Phase 2 — the doc example

`code_controller.dart:169-170` is corrected. This is not cosmetics: it is the
only example in the package showing how to follow the caret, it is wrong in a way
that silently misattributes the tint, and this spec is exactly the case it
purports to answer. The corrected text is in the contract. The example is
verified by a test rather than only by reading it.

## Phase 3 — verification

Per the repo's gates:

1. `flutter test --concurrency=2` — full suite, both files.
2. `dart analyze --fatal-infos`.
3. `dart format --output=none --set-exit-if-changed .`
4. The CI-identical coverage gate from `quickstart.md` §3, which must read
   `100.00% >= 100.00% — OK`.

## Risks

| Risk | Mitigation |
|---|---|
| The tint does not follow the caret because nothing rebuilds on a selection change | `research.md` R2 argues it does; `tasks.md` carries the behavioural test rather than trusting the argument. If RED, add a listener in `initState` — the only place one would go. |
| Widening the layer gate breaks a #86 test | The gate widens conjunctively and the caret logic reads a null-default field, so all eleven #86 tests pass unmodified. They are run first, before the new ones, so a failure is unmistakable. |
| `RangeError` from `characterIndexToLineIndex` crashes every editor | The guard in R4, with one test per caret state (no selection, end of text, `code` lagging). |
| A branch is unreachable and the 100% gate fails | The `??`-chain's three outcomes and the guard's three outcomes are all reachable and each has a named test. If a branch still proves dead, it goes to `EXEMPT_LINES` with a written reason, renumbered by line. |
| The gutter is expected too | Upstream said "line or line number"; `spec.md` records the row as the answer and the gutter as explicitly out of scope, so the reviewer sees the decision rather than discovering an omission. |

## Complexity budget

Three files, one field, one derived value, one `??` chain, one conjunctive gate,
one doc example. No new widgets, no new public types, no new listeners unless a
test proves one necessary.
