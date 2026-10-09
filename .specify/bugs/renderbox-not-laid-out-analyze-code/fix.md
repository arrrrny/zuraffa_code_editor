# Bug Fix Log: RenderBox was not laid out when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Issue**: 32

## Changed

- `lib/src/code_field/code_field.dart`
  - Added `bool get _isEditorBoxLaidOut` — `box != null && box.hasSize` on the
    editor key's render object.
  - `_onTextChanged` reads `_editorOffset` and calls `rebuild()` only inside the
    guard. The previous `_codeScroll != null && _editorKey.currentContext !=
    null` check only established that the box was *mounted*, never that it was
    laid out.
  - `_updatePopupOffset` returns early when the guard is false, before the
    `setState` that would otherwise throw mid-frame.
- `test/src/code_field/code_field_notify_before_layout_test.dart` (new)
  - `_NotifyOnLayout` / `_RenderNotifyOnLayout`: a `SingleChildRenderObjectWidget`
    whose `performLayout()` calls a callback after laying out its child, so the
    callback runs inside `flushLayout`.
  - Test 1: a notification fired from that sibling, with the `CodeField` after it
    in a `Column`, asserts nothing.
  - Test 2: the same notification followed by a frame, so the deferred
    offset work still happens.

## Not changed

- `GutterWidget`'s `AnimatedBuilder` mid-frame `setState` — separate pre-existing
  defect, recorded in `assessment.md`.
- `scrollOffsetOrZero` — already fixed under issue #10.

## Verification limits

- `_isEditorBoxLaidOut` has two false branches and one true branch; only the
  true branch carries behavior, and it is covered by every existing
  `CodeField` widget test. The false branch is covered by the two new tests.
- The `_updatePopupOffset` early return is not independently distinguishable in
  a widget test (the popup is not shown by default); it is reached through the
  same notification as `_onTextChanged`, which is what the new tests drive.
