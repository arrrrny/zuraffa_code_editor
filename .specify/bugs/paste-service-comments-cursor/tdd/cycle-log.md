# TDD cycle log: paste-service-comments-cursor

Date: 2026-10-10 · Branch: `bug/paste-service-comments-cursor` (based on
`origin/master` @ `8fc9fc6`)

## RED

Wrote `test/src/code_field/code_controller_paste_hidden_test.dart` (3 tests)
**before** touching `lib/src/code_field/code_controller.dart`, then ran it
against unmodified master:

```
00:00 +2 -1: Some tests failed.
Failing tests:
  …caret lands at the end of the pasted run
    Expected: 92
    Actual:   60
```

2 pass (guards), 1 fails — exactly the reported caret position.

## GREEN, attempt 1 — rejected

Applied the *unified* rule: in the `newValue.text != _code.visibleText` block,
always use `_code.hiddenRanges.cutSelection(selectionSnapshot)`.

Care test went green (92), but the full suite broke:

```
code_controller_folding_editing_test.dart: CodeController. Folding. Deleting
folded blocks. When deleting 2nd identical folded block, 1st one incorrectly folds
  Expected: TextSelection.collapsed(offset: 13)
  Actual:   TextSelection(baseOffset: 25, extentOffset: 26)
  Expected: TextSelection.collapsed(offset: 13)  (from the upstream TODO pin)
```

Root cause of the break: that test's `replacedSelection` on a **non-collapsed**
selection takes the `length >` branch, where the caret must *collapse* to the
start of the newly hidden text (`replacedText`), not round-trip through
`cutSelection`. The unified rule is too broad.

## GREEN, attempt 2 — accepted

Narrowed the rule to the collapsed-caret case:

```dart
if (newValue.selection.isCollapsed &&
    newValue.text.length > _code.visibleText.length) {
  newValue = TextEditingValue(
    text: _code.visibleText,
    selection: _code.hiddenRanges.cutSelection(selectionSnapshot),
  );
} else if (newValue.text.length > _code.visibleText.length) {
  newValue = newValue.replacedText(_code.visibleText);
} else {
  newValue = TextEditingValue(
    text: _code.visibleText,
    selection: _code.hiddenRanges.cutSelection(selectionSnapshot),
  );
}
```

```
test/src/code_field/code_controller_paste_hidden_test.dart → 3/3
flutter test → 365/365
dart analyze lib test → No issues found!
dart format → clean
```

## REFACTOR

- Extracted the shared `TextEditingValue(text: _code.visibleText, selection: …)`
  into the branch shape above. Considered hoisting it above the `if`, but the
  three branches assign different selections, so the current shape is the
  clearest.
- Post-review: the first and third arms had identical bodies, so the
  conditional collapsed to two arms — `!isCollapsed && length >` →
  `replacedText`, else → the round trip. Behaviour identical; full suite
  still green.
- No comment added inside `lib/` beyond the branch condition itself — the two
  existing comments already say what their branch does, and the condition is
  self-describing. (The reasoning lives in `fix.md` / `assessment.md`, where a
  reviewer will actually look for it.)

## Mutation check

Reverting the added branch (deleting the `isCollapsed` arm) puts the caret test
back to RED at 60. Removing `isCollapsed` from the condition re-breaks the
folded-block test.
