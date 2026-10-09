# Assessment: Cursor moves incorrectly when pasting code with service comments

- **Slug**: paste-service-comments-cursor
- **Issue**: 43 (upstream `akvelon/flutter-code-editor#88`)
- **Severity**: medium
- **Reproducible on this fork**: yes, in the exact form the report describes
- **Labels**: bug

## Symptom

Pasting a block of code that contains `// [START …]` / `// [END …]` service
comments puts the caret near the start of the pasted region instead of at the
end of it.

## Root cause

`CodeController`'s `value` setter
(`lib/src/code_field/code_controller.dart`) runs the framework's
`TextEditingValue` through the editor's hidden-range accounting:

```dart
final selectionSnapshot = code.hiddenRanges.recoverSelection(
  newValue.selection,
);
_updateCodeIfChanged(editResult.fullTextAfter);

if (newValue.text != _code.visibleText) {
  if (newValue.text.length > _code.visibleText.length) {
    // Manually typed in a text that has become a hidden range.
    newValue = newValue.replacedText(_code.visibleText);
  } else {
    // Some folded block is unfolded.
    newValue = TextEditingValue(
      text: _code.visibleText,
      selection: _code.hiddenRanges.cutSelection(selectionSnapshot),
    );
  }
}
```

`selectionSnapshot` is the caret recovered into the **full** text — the space
where the framework's offset is still meaningful. But in the
`newValue.text.length > _code.visibleText.length` branch that snapshot is
discarded and the caret is recomputed from a text diff by
`TextEditingValue.replacedText`, which collapses the caret to
`getChangedRange(...).start`.

That heuristic is right when a *single character* the user just typed turns a
line into a hidden range — the caret belongs at the start of the newly hidden
text. It is wrong for a **multi-line paste**: the changed range then spans
every service comment inside the pasted run, so its `start` is the *first*
comment in the pasted block, and the caret lands there instead of after it.

Measured on master with the report's own input:

| | value |
|---|---|
| framework caret (end of the 164-char visible text it built) | 164 |
| `recoverSelection` → full-text caret | **183** (end of full text) |
| `cutSelection` → correct caret in the re-derived 92-char visible text | **92** |
| `replacedText` → caret actually used | **60** (`getChangedRange(...).start`) |

So the caret was thrown away and rebuilt from a diff that answers the wrong
question.

## Why the fix is narrow

The `else` branch (folded block unfolded) already does exactly the right thing
with `selectionSnapshot`. The two other behaviours that share the
`length >` branch must be preserved:

- a **collapsed** caret with newly hidden text (typing `/` to open a foldable
  block) — the caret must stay put, which is what `cutSelection` gives;
- a **non-collapsed** selection whose replacement became a hidden range
  (`replacedSelection` of a run that turns into a service comment) — the caret
  must collapse to the start of the newly hidden text, which is what
  `replacedText` gives. This is the case pinned by
  `test/src/code_field/code_controller_folding_editing_test.dart`
  ("When deleting 2nd identical folded block, 1st one incorrectly folds",
  itself marked `TODO(alexeyinkin): Fix` upstream), and by
  `code_controller_hidden_ranges_test.dart`
  ("A typed-in service comment becomes a hidden range").

A collapsed caret is the paste/typing case the framework positions at the end
of an inserted run; a non-collapsed selection is the replace-selection case
where the old collapse heuristic is correct. Splitting on
`newValue.selection.isCollapsed` therefore fixes the paste without touching
either pinned behaviour — confirmed empirically: the unified
`cutSelection` rule breaks exactly the "deleting 2nd identical folded block"
test, the narrowed rule keeps all 366 tests green.

## Acceptance criteria

- [x] Paste of code containing service comments leaves the caret at the end of the pasted run
- [x] `fullText` keeps the pasted content verbatim (only tabs → spaces)
- [x] Typing that turns a line into a hidden range keeps the caret put (pinned by an existing test)
- [x] Replacing a selection that becomes a hidden range still collapses to the start (pinned by an existing test)
- [x] Unfolding a block still recovers the caret (pinned by an existing test)
- [x] Full suite green, `dart analyze` clean, `dart format` clean

## Out of scope

- `GutterWidget`'s mid-frame `setState` (the other defect in the
  notification-mid-frame family), recorded in
  `.specify/bugs/renderbox-not-laid-out-analyze-code/assessment.md`.
- Whether the caret should be *selected* rather than collapsed after a paste
  (upstream's screenshot shows a collapsed caret).
