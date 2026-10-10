# Spec: gutter-alignment

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/6
(upstream #312). Layer 1 (vertical drift) is already fixed and pinned by
test/src/gutter/gutter_alignment_test.dart. This spec covers layer 2.

## Requirement

Users must be able to inset the whole gutter column without forking:
`GutterStyle.padding`, default `EdgeInsets.zero`, applied around the
number/error/folding grid.

## Acceptance

- `GutterStyle().padding == EdgeInsets.zero`; `GutterStyle.none` too.
- `copyWith` carries `padding`.
- Setting `padding: EdgeInsets.only(left: 4, top: 2)` shifts the whole
  gutter column by exactly those insets; the row pitch is unchanged.
- Existing gutter rendering with default padding is unchanged (full
  suite green).

## Non-goals

- The `copyWith` dropping `showFoldingHandles` follow-up bug (tracked
  separately).
