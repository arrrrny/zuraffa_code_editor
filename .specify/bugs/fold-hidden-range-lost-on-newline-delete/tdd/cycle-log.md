# Cycle log: fold-hidden-range-lost-on-newline-delete

Upstream: `akvelon/flutter-code-editor#175` — "Hidden ranges of folded foldable
block gets removed when you delete one of the consecutive new line chars after
the block". Fork issue:
[arrrrny/zuraffa_code_editor#160](https://github.com/arrrrny/zuraffa_code_editor/issues/160).

## Red

`test/src/folding/fold_survives_newline_after_fold_test.dart` written against
master `2d42e46` with the issue's shape — a folded block, then a run of blank
lines, then a second block:

```dart
const example = 'a {\n  body();\n}\n\n\n\nb {\n  y();\n}\n';
controller.foldAt(0);
controller.selection = const TextSelection(baseOffset: 4, extentOffset: 5);
controller.value = controller.value.replacedSelection('');
```

Red on master: the visible text loses the newline correctly
(`a {}\n\n\nb {\n  y();\n}\n`) but `hiddenRanges.ranges` is **empty** — the fold
is gone. The single red test was the repro; the other three were written as its
consequences (blank line further away, still unfoldable, content change still
drops the fold) and three of the four were already green.

## The harness hid the literal keystroke

The first attempt at a repro drove `wt.sendKeyEvent(backspace)` as the first
keystroke after `controller.foldAt(0)` and observed nothing: the keystroke is
swallowed, the text does not change, and no defect is visible. Re-routed through
the widget's own selection path (`selectFromHome` + `replacedSelection('')`),
which is what a real selection edit does.

That near-miss was the clue to the root cause. The keystroke *is* refused — by
the guard upstream added for `#222`, `Code.getEditResult` at
`lib/src/code/code.dart:492`. It refuses a collapsed single-character deletion
that would remove a folded block, and `oldSelection.isCollapsed` is why it sees
Backspace and does not see a selection. So #175's literal report is already
covered and the live defect is the selection path. This was settled rather than
assumed: the guard was left in its original form and its one contract test
(`Code.getEditResult keeps text on backspace into a folded block`) was left
green.

## Root cause — pinned by a print, not by reading

`_editTouchedHiddenContent` decided "did this edit touch the hidden content?"
with a guessed line span. A `print` of `changedOldLines` at the top of the
method settled both directions at once:

```
#175 (fold must SURVIVE): FoldableBlock(0, 2)  changed = TextRange(2, 3)  }
#108 (fold must DROP):    FoldableBlock(3, 4)  changed = TextRange(3, 5)  }
```

The block's true hidden span is `firstLine .. (closing ? lastLine - 1 :
lastLine)`, derived from `Code.foldableBlockToHiddenRange`:

- **#175** — the closer `}` is line 2, so the hidden span is `0..1`. The edit is
  `2..3`, entirely outside it. The fold must survive, and the old code
  (`firstLine + 1 .. lastLine` = `1..2`) said `1..2` intersects `2..3` → dropped.
- **#108** — the closer `}` is line 4, so the hidden span is `3..3`, a two-line
  block whose entire hidden content is the newline ending line 3. The edit is
  `3..5`, which starts inside it. The fold must drop, and the old code
  (`4..4`) said no → survived. Wait — #108 is green on master; the #108 fix
  (`6c9fa1a`) is what introduced `.. lastLine`, over-reaching to make #108 drop.

Both bounds of the old span were wrong *because of that over-reach*: `firstLine
+ 1` exempted the first line although its trailing newline is the first hidden
character, and `.. lastLine` hid the closing row although the range stops at
that row's start so the closer stays on screen.

## Green

```dart
final firstHiddenLine = oldFoldedBlock.firstLine;
final lastHiddenLine = oldLines[oldFoldedBlock.lastLine].isClosingLine
    ? oldFoldedBlock.lastLine - 1
    : oldFoldedBlock.lastLine;
return firstHiddenLine < changed.end && lastHiddenLine >= changed.start;
```

`firstLine < changed.end && lastHiddenLine >= changed.start` is the standard
half-open overlap test on the hidden span.

## Attempt 1 — also exempting the first line

The next attempt exempted the first line as well, reasoning that it is the row
that stays on screen so an edit touching only it cannot hide anything. Red: the
#108 identical-blocks test in
`test/src/code_field/code_controller_folding_editing_test.dart`. With the first
line exempt, the span for #108's two-line block (`3..4`) became empty and the
fold survived again. Reverted — the first line *is* part of the span; only the
closer row is not.

## Refactor

- The closing-row test moved from a private `Code._isClosingLine` static to
  `CodeLine.isClosingLine`, a public getter. Both callers — the hidden-range
  builder and the re-match — now read one definition, and the getter itself is
  unit-testable (3 tests) rather than reachable only through folding behaviour.
- The doc comment on `_editTouchedHiddenContent` states the span's derivation
  and names the issue, because the `- 1` is the part a future reader will
  otherwise misread as an off-by-one.

## Verification

- `flutter test --concurrency=2 --coverage` → +982, all passed.
- `python3 tool/coverage_gate.py --min 100` → 100.00% (3635/3635 over 110 files).
- `dart analyze --fatal-infos` → clean; `dart format --output=none
  --set-exit-if-changed lib test` → clean.

## Note on the coverage helper

The gate run first failed at `loading test/coverage_helper_test.dart`. The file
is generated by CI from `.github/workflows/dart.yaml`; a local copy had been
generated with `package:/src/...` URIs, which resolve to nothing. With the
workflow's own form — `find lib ! -name '*_web.dart' -name '*.dart' | cut -c4-`
(the leading `/` is the path separator after the package name) — the helper
loads and the run is the real one. The helper is generated output and is never
committed.
