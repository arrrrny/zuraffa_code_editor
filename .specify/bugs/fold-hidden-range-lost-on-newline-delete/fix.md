# Fix: a fold survives an edit to the newline that follows it

Status: **applied** — branch `bug/fold-hidden-range-lost-on-newline-delete-175`,
base master `2d42e46`.
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/folding/foldable_block_matcher.dart` | `_editTouchedHiddenContent` now measures the block's real hidden-line span instead of guessing it: the first line **counts** (the hidden range starts at the newline ending it), and the closing row is **dropped from the tail** when the last line is a closing row, because `Code.foldableBlockToHiddenRange` ends the range at that row's start and leaves it on screen. The over-reach on the tail (`.. lastLine`) was introduced by the #108 fix. |
| `lib/src/code/code_line.dart` | `CodeLine.isClosingLine`, a new public getter carrying the `)` / `]` / `}` leading-token test that `Code._isClosingLine` held as a private static. One definition, two callers. |
| `lib/src/code/code.dart` | `Code._isClosingLine` removed; `foldableBlockToHiddenRange` reads `lastLine.isClosingLine`. The #222 guard at `:492` is untouched and in its original form. |
| `test/src/folding/fold_survives_newline_after_fold_test.dart` | **new** — 4 tests on the issue's exact shape: the fold survives deleting the newline right after the closer row, survives deleting a blank line further away, stays unfoldable afterwards with its content intact, and is still dropped when the hidden content itself changes. |
| `test/src/code_field/code_controller_folding_editing_test.dart` | new group `Deleting a newline after a folded block` — one `testWidgets` that drives the defect through the widget's own selection-edit path (`replacedSelection('')` over the newline that ends the closer row), which is the path the #222 collapsed-caret guard does not cover. |
| `test/src/code/code_line_test.dart` | new group `CodeLine.isClosingLine` — 3 tests: a leading `)`, `]` and `}` with leading whitespace and with code after the token; and the negatives (a `}` mid-line, a plain word, a closing token inside a comment). |
| `CHANGELOG.md` | `### Fixed` entry under Unreleased. |

## Why the first line counts and the closer does not

The hidden character range a fold actually hides is `(newline ending the first
line) .. (start of the closing row)`. Two consequences that the old code got
backwards:

- **The first line is part of the span.** Its trailing newline is the first
  hidden character, so an edit starting on that newline does touch hidden
  content. This is also the row a two-line block (`}` on the very next row)
  whose entire hidden content is that newline — the #108 case.
- **The closing row is not part of the span.** The range stops at its start, so
  the closer and the newline ending it are that row's own. Deleting the newline
  *after* the closer touches neither, so the fold must survive — #175.

A first attempt that also exempted the first line (treating it as always
visible, as it is on screen) broke the #108 test and was reverted.

## Verification

- `flutter test --concurrency=2 --coverage` → **+982, all tests passed**.
- `python3 tool/coverage_gate.py --min 100` → **100.00% (3635/3635 lines over
  110 files)** — no new exemption added or needed. The `isClosingLine` getter is
  covered by three unit tests and the `lastHiddenLine` branch by the #175 and
  #108 cases.
- `dart analyze --fatal-infos` → No issues found.
- `dart format --output=none --set-exit-if-changed lib test` → clean.

## Scope note

The #222 guard (`lib/src/code/code.dart:492`) is deliberately unchanged. Its
whole contract is the single test `Code.getEditResult keeps text on backspace
into a folded block`, it is keyed on `oldSelection.isCollapsed`, and it already
refuses the literal Backspace reproduction of #175. The defect this PR fixes is
the selection-edit path that the guard cannot see.
