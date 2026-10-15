# Assessment: fold lost on a newline deletion after a folded block

Status: **confirmed** — reproduces on master `2d42e46`.
Source issue: ./issue.md (upstream `akvelon/flutter-code-editor#175`).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Reported symptom

A folded foldable block followed by a run of blank lines loses its fold when one
of the blank lines' newline characters is deleted. The hidden content renders
back in.

## Reproduction

Measured on master. Document:

```dart
const code = 'a {\n  body();\n}\n\n\n\nb {\n  y();\n}\n';
```

`controller.foldAt(0)` — the `a {` block, whose closer `}` is on its own row —
produces `hiddenRanges = [HiddenRange(3, 14, 0, 2, false)]` and
`visibleText = 'a {}\n\n\n\nb {\n  y();\n}\n'`.

The block is `FoldableBlock(0, 2, braces)`. Its hidden range covers characters
`3..14`, which is line 1 (`  body();`) only — `foldableBlockToHiddenRange` ends
the range at the closer row's *start* (character 14), so the closer row stays
visible.

| edit | fold |
|---|---|
| select visible `4..5` (the newline ending the closer row) and delete | **lost** |
| select visible `5..8` (a blank line further away) and delete | kept |

So `hiddenRanges` becomes `[]`, `foldedBlocks` becomes `{}`, and the visible
text comes back `a {\n  body();\n}\n\n\nb {…`.

### Why the literal keystroke is masked

The reporter's video shows Backspace/Delete. On master that path is already
refused by the guard upstream added for #222 (`code.dart:492`):

```dart
if (oldSelection.isCollapsed &&
    visibleAfter.text.length == visibleText.length - 1 &&
    foldedBlocks.any((block) => block.lastLine >= firstChangedLine &&
                                block.lastLine < lastChangedLine)) {
  return CodeEditResult(fullTextAfter: text, linesChanged: const TextRange(start: 0, end: 0));
}
```

Its author is **yescorp — the same person who filed #175**. With the guard
disabled the full suite (988 tests) has exactly one failure:
`code_get_edit_result_test.dart` → "keeps text on backspace into a folded
block". So the guard's entire contract is that single case.

**A selection edit bypasses the guard entirely** (it is keyed on
`oldSelection.isCollapsed`), which is how #175 still reproduces on master.

## Root cause

The fold is re-established by `FoldableBlockMatcher` in `Code.foldedAs` →
`_copyWithFolding`, and `_addIfMatch` drops a block whose hidden content the
edit touched. That predicate was:

```dart
final firstHiddenLine = oldFoldedBlock.firstLine + 1;
final lastHiddenLine = oldFoldedBlock.lastLine;
return firstHiddenLine < changed.end && lastHiddenLine >= changed.start;
```

`lastHiddenLine` is the defect: it uses `block.lastLine`, but the closer row is
*visible* content — `foldableBlockToHiddenRange` ends the range at that row's
start precisely so the closer stays on screen. For the #175 edit the measured
`changedOldLines` is `TextRange(start: 2, end: 3)`, so
`1 < 3 && 2 >= 2` → true → the fold is dropped.

The over-reach was introduced by our own #108 fix (`6c9fa1a`, two days before
this issue was assessed), when `changedOldLines` was threaded into the matcher.

## The two shapes the predicate must separate

Measured with a debug `print` in `_editTouchedHiddenContent`:

- **#175 (must keep the fold):** block `FoldableBlock(0, 2, braces)` in
  `a {\n  body();\n}\n\n\n\nb {\n  y();\n}\n`,
  `changedOldLines = TextRange(start: 2, end: 3)`. The closer row `}` is line
  `2`, so the hidden line span is `0..1` (the newline ending line 0 through the
  line before the closer). The edit lands on 2..3 — outside it.
- **#108 (must drop the fold):** block `FoldableBlock(3, 4, braces)` in
  `{\nif (true) {\n}\nif (true) {\n}\n}`,
  `changedOldLines = TextRange(start: 3, end: 5)`. The closer row `}` is line
  `4`, so the hidden line span is `3..3` — the block is two rows, so its entire
  hidden content is the newline ending line 3. The edit starts on line 3 —
  inside it.

The discriminator is the block's **true hidden line span**, not
`firstLine + 1 .. lastLine`:

```dart
final firstHiddenLine = oldFoldedBlock.firstLine;
final lastHiddenLine = oldLines[oldFoldedBlock.lastLine].isClosingLine
    ? oldFoldedBlock.lastLine - 1
    : oldFoldedBlock.lastLine;
return firstHiddenLine < changed.end && lastHiddenLine >= changed.start;
```

`CodeLine.isClosingLine` is a new getter holding the closing-row test that
`Code._isClosingLine` used to carry inline; `Code.foldableBlockToHiddenRange`
now reads it, so the definition lives in one place.

## Fix direction

The only change is in `_editTouchedHiddenContent`. An earlier attempt narrowed
the span to `firstLine + 1 .. lastLine - 1` using `isClosingLine` and **broke
the #108 test**:

```
When deleting 2nd identical folded block, 1st one does not fold [E]
  Expected: ┤{\nif (true) {\n}\nif (true) ;}├
  Actual:   ┤{\nif (true) {\n}\nif (true) {};}├
```

because for a two-row block the hidden content *is* the newline ending the
first line, and excluding the first line from the span leaves nothing to test.
The fix therefore keeps the first line in the span and drops only the closer
row.

## Risk

- The `lastHiddenLine` reduction changes behaviour for every closing-row block,
  so the whole `Editing` group in `code_controller_folding_editing_test.dart`
  is the guard. Full suite green (989 tests).
- `isClosingLine` is public on `CodeLine`; `Code`'s private static was removed
  in favour of it, so there is one definition, not two.

## Verification plan

`test/src/folding/fold_survives_newline_after_fold_test.dart` (new) plus one
`testWidgets` in `code_controller_folding_editing_test.dart`:

- deleting the newline right after the closer row → fold kept, hidden content
  kept hidden (the #175 case, red on master)
- deleting a blank line further away → fold kept (guard against over-fixing)
- the block is still unfoldable afterwards
- the hidden content changing still drops the fold (`controller.fullText`)
- the same edit through a real `CodeField` selection
