# Bug Assessment: Auto-scroll does not follow the caret while typing

- **Slug**: auto-scroll-caret
- **Created**: 2026-10-10
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/42
  (synced from upstream `akvelon/flutter-code-editor#316`)
- **Verdict**: valid, reproduced
- **Severity**: high (typing past the bottom of the field is unusable)

## Symptom

Typing line by line in a `CodeField` does not scroll the caret into view.
Once the text grows past the visible height the new lines are laid out
below the field's bounds and the user has to scroll manually — and in the
layout the field ships with, even manual scrolling is impossible because
the field grows instead of scrolling.

## Reproduction

Widget test, `test/src/code_field/auto_scroll_caret_test.dart`:

1. Pump `MaterialApp > Scaffold > SizedBox(height: 200) > CodeField`.
2. Tap the field (show keyboard) and `enterText` 40 lines.
3. Assert the `Scrollable` inside the `EditableText` has `pixels > 0`.

On master this **fails two ways**:
- `A RenderFlex overflowed by 792 pixels on the bottom` — the `Column` in
  `_wrapInScrollView` (`lib/src/code_field/code_field.dart:378`) lets the
  field grow to its full content height and clips the overflow.
- The scroll assertion fails (`Expected: a value greater than <0>`).

## Root Cause

`_wrapInScrollView` places the `TextField` in a `Column(mainAxisSize:
.min)` whose only bounded child is the invisible spacer; the field itself
is a non-flex child, so the `Column` lays it out with unbounded vertical
constraints. A `TextField` with the default `maxLines: null` then sizes
itself to the whole text, and:

- the field never creates internal scroll extent, so Flutter's
  caret-reveal (`EditableText._scheduleShowCaretOnScreen` →
  `scrollController.animateTo` + `showOnScreen`) has nothing to scroll;
- the linked gutter `_numberScroll` never moves either;
- the content simply overflows the viewport and is clipped.

The `LayoutBuilder` already knows the available height
(`constraints.maxHeight`) but only forwarded `maxWidth` into the wrapper.

## Proposed Remediation

Bound the field by the editor box height: pass `constraints.maxHeight`
into `_wrapInScrollView` and wrap the non-`expands` field in a
`ConstrainedBox(maxHeight: ...)`. The field's own vertical scrollable
(bound to `_codeScroll`) then owns the scrolling, and Flutter's built-in
caret-reveal-while-typing works again — including the gutter sync through
the `LinkedScrollControllerGroup`.

Upstream has the same defect (issue #316 is still open there); this is a
fork fix, not a port.

## Risks & Considerations

- Unbounded-height hosts (`CodeField` inside an unbounded parent) get
  `maxHeight == double.infinity`, a no-op `ConstrainedBox` — behaviour
  unchanged.
- The `expands: true` path is untouched (`Expanded` already bounds the
  field).
- Existing widget tests that rely on the field growing with its content
  (e.g. `windowSize` rebuild assertions) could shift; the full suite is
  the regression gate.
