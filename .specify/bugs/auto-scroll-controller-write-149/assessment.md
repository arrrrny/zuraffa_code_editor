# Bug Assessment: Auto-scroll does not follow the caret on a controller write

- **Slug**: auto-scroll-controller-write-149
- **Created**: 2026-10-13
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/149
  (upstream `akvelon/flutter-code-editor#316`)
- **Verdict**: valid — the *typing* path works, the *controller* path does not
- **Severity**: low (typing works; the gap is the host/programmatic API)

## Symptom

A host that writes the document line by line through `CodeController`
(`controller.text = …`, `controller.selection = …`) moves the caret past the
bottom of the viewport with no scroll, and the caret has to be found by hand.
The identical edit made by typing scrolls it into view.

## Reproduction

Widget test, `test/src/code_field/programmatic_write_reveals_caret_test.dart`:

1. Pump `MaterialApp > Scaffold > SizedBox(height: 200) > CodeField`.
2. Tap the field to focus it.
3. Loop 40 times: `controller.text = text + 'line $i\n'`, then
   `controller.selection = TextSelection.collapsed(offset: text.length)`,
   one `pump()` per iteration.
4. Assert the `Scrollable` inside the `EditableText` has `pixels > 0`.

On master this **fails**: `pixels == 0.0` at every sample, with
`maxScrollExtent == 816.0` — the extent is there, nothing scrolls to it.

Two control probes measured first, on the same tree:

- `tester.enterText` 40 lines → pixels 0 → 816. Works.
- The same at human typing speed (80 ms per line, so the 500 ms analysis
  debounce runs between writes) → 0 → 456. Works.

So the regression is not in the layout (#42's fix holds) and not in the
debounce: it is the *path* the value travels.

## Root Cause

`EditableText` runs its caret reveal — `_scheduleShowCaretOnScreen` — from
`userUpdateTextEditingValue` (`packages/flutter/lib/src/widgets/editable_text.dart:5147`),
which is the method every platform keystroke, IME update and intent-driven
selection arrives through. A controller write notifies
`_didChangeTextEditingValue` (`editable_text.dart:4918`) instead, and that
listener only rescues an invalid selection, updates the remote editing value
and toggles the cursor timer — it deliberately does not reveal. Verified by
reading Flutter 3.47.5: `_scheduleShowCaretOnScreen` has exactly four call
sites (`userUpdateTextEditingValue`, `_handleFocusChanged`, the
metrics-change path and `_performSpellCheck`), none of them the controller
listener.

Two consequences for the fix, both verified by reading and by probe:

1. `RenderEditable` **is** its own vertical viewport — `EditableText` passes
   the `Scrollable`'s `offset` into it (`rendering/editable.dart:1071,2436`)
   and paints the text shifted by `offset.pixels`
   (`rendering/editable.dart:1697-1698`). There is no `RenderViewport` between
   the `RenderEditable` and the root of the field's subtree (probe: the parent
   chain runs `_RenderSizeChangedWithCallback → RenderSemanticsAnnotations →
   RenderLeaderLayer → … → RenderRepaintBoundary → … → _RenderLayoutBuilder`
   with no viewport until the field's *horizontal* `SingleChildScrollView`).
   So `RenderObject.showOnScreen` — the other half of the framework's reveal —
   finds no vertical viewport to move and is a no-op on that axis; the offset
   has to be computed and driven from here.
2. `RenderEditable.getLocalRectForCaret` returns a rect **relative to the
   visible band**, not to the document: the same caret reads y = 912 at
   `pixels == 0` and y = 412 at `pixels == 500`. So the caret is in view
   exactly when it lies inside `[0, viewportDimension]`.

## Proposed Remediation

Drive the reveal on the controller path in `CodeField`:

- `_onTextChanged` compares the controller value against the last one it saw,
  so an analysis/search/popup notification is told apart from one that moved
  the caret.
- On a value change, if the field has focus, schedule a post-frame reveal:
  read the caret rect from the laid-out `RenderEditable`, scroll the code
  scrollable by the smallest delta that puts the rect inside the band, then
  hand the same rect to `showOnScreen` for the horizontal axis and any
  scrollable the host wrapped the field in — the two halves of the
  framework's own reveal, in the order it makes them.
- Focus gates it, matching `EditableText._handleFocusChanged`: a host loading
  a document the user has not opened yet must not have the viewport yanked to
  the caret, and the reveal happens on the focus change that follows anyway.
- `position.allowImplicitScrolling` gates it too, so a drag, a fling or a
  host-disabled physics keeps ownership of the field.

## Risks & Considerations

- The typing path now runs the reveal twice (the framework's and this one).
  Both target the same offset; the extra one lands instantly rather than over
  the framework's 100 ms animation. The full suite is the regression gate,
  and the existing typing reveal test stays green.
- A write made while the field is unfocused no longer changes the scroll
  offset from what master does — pinned by test.
