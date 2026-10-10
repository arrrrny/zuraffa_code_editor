# Bug Assessment: Gutter numbers and code text not aligned; add gutterPadding

- **Slug**: gutter-alignment
- **Created**: 2026-10-09
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/6
- **Verdict**: valid (vertical drift already fixed; padding API still missing)
- **Severity**: low

## Report (verbatim or summarized)

Upstream #312: gutter numbers and code text are not aligned; users fork the
library to add `gutterPadding` and it "aligns perfectly". The
match-the-height-in-both-textStyles workaround does not fix it for everyone.

## Symptom

Two layers:
1. Vertical drift of gutter rows off the code line grid — **already fixed** in
   this fork.
2. No API to fine-tune gutter padding — **still missing**.

## Reproduction

1. `CodeField(textStyle: TextStyle(height: 1.5, fontSize: 18))` — gutter rows
   used to fall back to font metrics; now pinned by the height copy below.
2. Any user wanting a few units of gutter inset has no property to set.

## Suspected Code Paths

- `lib/src/code_field/code_field.dart:483-518` — `_buildGutter()` copies
  `fontSize`, `fontFamily` **and `height`** from the code style into the gutter
  style, pinning both grids to identical line boxes. This is the fork's fix for
  layer 1.
- `test/src/gutter/gutter_alignment_test.dart` — already pins the invariant
  (unfolded + folded states, row pitch equals rendered line height). Green today.
- `lib/src/gutter/gutter.dart:31-40,76-88` — `GutterWidget.build` wraps the
  `Table` in a `Container` with only `EdgeInsets.only(right: style.margin)`.
  There is no user-facing padding knob — layer 2.
- `lib/src/line_numbers/gutter_style.dart` — `GutterStyle` has `margin` but no
  `padding` property.

## Root Cause Hypothesis

Layer 1 root cause (missing `height` in the copied gutter style) is fixed and
covered by regression tests. Layer 2 is a missing escape hatch: `margin` is a
fixed 10.0 default with no per-side control. Confidence: high (code read).

## Proposed Remediation

**Preferred**: add a `padding` property to `GutterStyle` (default
`EdgeInsets.zero`, so current rendering is byte-identical) and apply it in
`GutterWidget.build` between the vertical 16 inset and the `Container`, e.g.
`Padding(padding: EdgeInsets.symmetric(vertical: 16) + style.padding ...)` —
concretely, wrap the `Table`'s `Container` with the user padding inside the
existing vertical padding.

**Tests to add**:
- Default style renders unchanged (no extra padding → gutter rect identical to
  today's layout).
- `padding: EdgeInsets.only(left: 4)` shifts the number column right by 4
  logical pixels without changing row pitch (grid invariant stays pinned by the
  existing test).

**Follow-up (correction)**: the tracked claim named the wrong field —
`GutterStyle.copyWith` carries `showFoldingHandles` (and `_buildGutter`
only overrides `textStyle`/`errorPopupTextStyle`, so nothing is reset).
The field it actually dropped was `errorPopupTextStyle`, forwarded bare
in `copyWith`; fixed in this PR's review-fix pass, so no separate bug is
needed.

## Risks & Considerations

- Default must stay `EdgeInsets.zero` to avoid changing existing users' layout.
- `copyWith` should carry the new field too (same pattern as the follow-up bug).

## Open Questions

- None.
