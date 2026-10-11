# Assessment: Fold and unfold drop the current selection

- **Slug**: fold-unfold-deselects-106
- **Issue**: 106 (upstream `akvelon/flutter-code-editor#189`)
- **Severity**: low
- **Reproducible on this fork**: yes, for a selection the folded block covers
- **Labels**: bug

## Symptom

Upstream #189 is a screen recording with no written reproduction: a selection
is made, a fold toggle is clicked, and the selection is gone. The issue body
also claims the location is `lib/src/folding/fold_toggle.dart`, a path that
does not exist in this repo — the real path is `foldAt` / `unfoldAt` on
`CodeController` (`lib/src/code_field/code_controller.dart`), which both route
through `_getValueWithCode`.

The report's claim that the selection is dropped "even when it is untouched by
the fold" does **not** reproduce. Measured, driving a real mouse-drag
selection over `void method2()` and then tapping `void method1()`'s gutter
toggle:

| | value |
|---|---|
| selection before the tap | `TextSelection(58, 97)` |
| selection after the fold | `TextSelection(45, 84)` |
| selection after the unfold | `TextSelection(58, 97)` |

The selection is correctly shifted by the characters the fold hid and is
restored exactly by the unfold. The same holds at the controller level
(`foldAt(2)` / `unfoldAt(7)`).

What does reproduce is the case the recording is most likely showing: the
selection **covers** the block being folded. A selection on `    return;` and
its closing brace — the text `foldAt(1)` hides in full-text range `[42, 55]`:

| | value |
|---|---|
| selection before the fold | `TextSelection(43, 58)` |
| selection after the fold | `TextSelection(42, 45)` |
| selection after the unfold | `TextSelection(42, 45)` |

A caret inside the folded block behaves the same way (`47` → `42`, and stays
`42`), and a selection straddling the boundary loses its far end
(`[0, 44]` → `[0, 42]`, and stays `[0, 42]`).

So the defect is not that a fold refuses to show hidden text — it is that
**folding and unfolding are not inverse operations on the selection**. The
truncation is reasonable while the block is folded, but the visible text alone
cannot say what was truncated, so the unfold has nothing to restore.

## Root cause

`foldAt` and `unfoldAt` both end in:

```dart
super.value = _getValueWithCode(newCode);
```

and `_getValueWithCode` lifts the selection the field is showing into the full
text and immediately projects it back:

```dart
selection: newCode.hiddenRanges.cutSelection(
  _code.hiddenRanges.recoverSelection(value.selection),
),
```

A selection lives in the **visible** text. When the new hidden ranges swallow
part of it, `cutSelection` clamps those endpoints to the fold marker, and the
information needed to undo that clamping is discarded with the intermediate
full-text selection. The unfold then recovers the *truncated* selection, so
the lost offsets are gone for good.

The predicate for "the fold truncated the selection" is exact and cheap: lift
the truncated selection back through the new ranges and compare. If the round
trip does not return the selection, part of it fell inside a hidden range.

## Why the fix is narrow

The full-text selection is remembered for exactly as long as it is needed:
`_getValueWithCode` keeps the lifted selection only when the round trip proves
it was truncated, and it is dropped the moment anything else re-establishes the
selection in the visible text — a change from the field in the `value` setter,
or `applyHistoryRecord`, which carries a selection of its own. The result is
that folding is unchanged for every selection the fold does not cover, and
folding followed by unfolding is a no-op on the selection.

The two other things that reach `cutSelection` are untouched: the paste path
in the `value` setter (a caret the framework positioned at the end of an
inserted run, where recovering through the *new* ranges would move it into
hidden text — `.specify/bugs/paste-service-comments-cursor/assessment.md`),
and `applyHistoryRecord`, where the record is authoritative.

## Acceptance criteria

- [x] A selection the folded block covers is restored by unfolding it
- [x] A caret inside the folded block is restored by unfolding it
- [x] A selection straddling the fold boundary is restored by unfolding it
- [x] A selection the fold does not cover still tracks and restores exactly
- [x] Moving the selection while the block is folded is not undone by the unfold
- [x] Unfolding a different block does not resurrect a selection another fold hid
- [x] A keystroke after the round trip does not resurrect the folded selection
- [x] Full suite green, `dart analyze` clean, `dart format` clean, 100% coverage gate

## Out of scope

- Whether folding should refuse when the selection is inside the block. The
  recording gives no acceptance criteria, and refusing a fold the user asked
  for would be a bigger behavioural change than preserving the selection.
- The `TODO(alexeyinkin)` fold-state transfer between two textually identical
  but distinct blocks, tracked as #108.
