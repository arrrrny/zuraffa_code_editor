# #19 — Verification record

## What was checked

1. **The wiring.** `_numberScroll` and `_codeScroll` both come from one
   `LinkedScrollControllerGroup` (`code_field.dart:290-292`); the first goes to
   `GutterWidget`, the second to the editor's `TextField`. Both are disposed.
   No dead controller.
2. **Drag scrolling.** Six 20px drags on the editor, gutter offset tracked to
   within 1px, gutter never past its own `maxScrollExtent`.
3. **Jump to the bottom.** Gutter lands on its `maxScrollExtent` within 1px.
4. **`wrap: true`.** Same result with the wrapping row measurement active.

## Result

All four checks pass. The symptom in the report does not reproduce and the root
cause it names is absent on this fork.

## What lands

`test/src/code_field/line_numbers_follow_scroll_test.dart` — the three
regression tests above, with the fixture deliberately overflowing a 220px
viewport (60 lines) so the drag has somewhere to go.

## Follow-up

The "sidebar is too wide" half of the report is a design question, not a defect;
it deserves its own `spec` issue.
