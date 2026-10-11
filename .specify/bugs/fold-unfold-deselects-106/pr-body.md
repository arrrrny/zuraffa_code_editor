# Fix: fold and unfold no longer throw away the selection they cover (#106)

Closes #106 (upstream `akvelon/flutter-code-editor#189`).

## What was wrong

Upstream filed this as a screen recording with no written reproduction, and its
own location guess — `lib/src/folding/fold_toggle.dart` — does not exist in this
repo. The real path is `CodeController.foldAt`/`unfoldAt`, which both route
through `_getValueWithCode`.

A selection lives in the **visible** text, so the part of a selection that a
folded block hides can only be shown truncated, clamped to the fold marker.
That part is fine. The defect is in what happens next.

```dart
// lib/src/code_field/code_controller.dart — before
TextEditingValue _getValueWithCode(Code newCode) {
  return TextEditingValue(
    text: newCode.visibleText,
    selection: newCode.hiddenRanges.cutSelection(
      _code.hiddenRanges.recoverSelection(value.selection),
    ),
  );
}
```

The lifted full-text selection is computed and immediately projected back. When
the new hidden ranges swallow part of it, `cutSelection` clamps those endpoints
to the fold marker — and the information needed to undo that clamping is
discarded with the intermediate value. The unfold then recovers the
*truncated* selection, so the offsets the fold removed are gone for good.

## Measured on master (before)

`foldAt(1)` on this document hides full-text `[42, 55]`:

```java
private class MyClass {
  void method1() {
    return;
  }

  void method2() {
    return;
  }
}
```

| selection | after the fold | after the unfold |
|---|---|---|
| `TextSelection(43, 58)` — `    return;` and its brace | `TextSelection(42, 45)` | `TextSelection(42, 45)` |
| caret at `47` | `collapsed(42)` | `collapsed(42)` |
| `TextSelection(0, 44)` — straddling | `TextSelection(0, 42)` | `TextSelection(0, 42)` |

## What the report gets wrong

The report's own claim — "drop the current selection even when it is untouched
by the fold" — does **not** reproduce. Driving a real mouse-drag selection over
`void method2()` and then tapping `void method1()`'s gutter toggle:

```
mouse sel   : TextSelection(baseOffset: 58, extentOffset: 97)
after tap   : TextSelection(baseOffset: 45, extentOffset: 84)
after unfold: TextSelection(baseOffset: 58, extentOffset: 97)
```

Correctly tracked, correctly restored. The same holds at the controller level,
and it rules out the obvious suspects along the way — focus loss, the gutter's
`GestureDetector`, and the `FoldToggle` callback were each probed in isolation
and all preserved the selection. Only a selection the folded block covers is
affected.

## The fix

`lib/src/code_field/code_controller.dart`:

- new field `TextSelection? _selectionHiddenByFold`;
- `_getValueWithCode` remembers the lifted selection when cutting it through the
  **new** ranges and lifting it back does not return it — an exact predicate for
  "the fold truncated the selection", because the round trip returns the fold
  marker rather than the original endpoints. When the round trip *does* return
  it, nothing is remembered, which is why a fold the selection does not cover is
  byte-for-byte unchanged;
- the `value` setter clears the field — a change from the field re-establishes
  the selection in the visible text, so whatever a fold had truncated is no
  longer what the user is pointing at;
- `applyHistoryRecord` clears it — the record carries a selection of its own.

Deliberately unchanged: while the block is still folded, a selection it covers
shows only its visible remainder, clamped to the fold marker. Hidden text has
no visible representation to select, and undoing the truncation there would
need a selection the field cannot render.

## Tests

`test/src/code_field/fold_unfold_keeps_selection_test.dart` (new, 7 tests):

| test | red without the fix? |
|---|---|
| `a selection inside the folded block survives the round trip` | **yes** — `Expected: <24> Actual: <42>` |
| `a caret inside the folded block survives the round trip` | **yes** — `Expected: <47> Actual: <42>` |
| `a selection straddling the fold survives the round trip` | **yes** — `Expected: <TextSelection(baseOffset: 0, extentOffset: 44, ...)> Actual: <TextSelection(baseOffset: 0, extentOffset: 42, ...)>` |
| `a selection outside the folded block is not resurrected` | no (regression pin — the pre-existing correct behaviour) |
| `moving the selection after the fold forgets the folded one` | no (regression pin) |
| `unfolding another block does not resurrect the folded selection` | no (regression pin) |
| `the remembered selection does not leak into a plain keystroke` | **yes** — `Expected: <44> Actual: <47>` |

The last one is the guard that matters for the field: a keystroke after a round
trip must shift the *restored* selection, not resurrect the folded one.

## Verification

- `flutter test` — **776/776 passing** (7 new)
- `dart analyze` — clean; `dart format` — clean
- Coverage gate — **100.00% (3389/3389 lines over 106 files)**, no change to
  `EXEMPT_FILES` / `EXEMPT_LINES`
- `./scripts/local_ci.sh` — every step of `.github/workflows/dart.yaml`, 0
  failures

Pre-existing and out of scope: `no_language_keystroke_test.dart` is a wall-clock
ratio pin that has twice failed under full-suite load (66 ms median against a
100 ms bound in isolation, green here). Untouched by this change.

Spec/assessment/TDD chain: `.specify/bugs/fold-unfold-deselects-106/`.
