# Spec: gutter-icon-row-height-107

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/107
(upstream akvelon/flutter-code-editor#312, #215).

## Requirement

When the code's rendered line box is shorter than the gutter's fixed 16px icon
columns, the icon must not set the `Table` row's height. Every gutter row must
stay exactly one code line tall so the numbers stay on the code's grid however
small the code font is.

## Acceptance

- With `textStyle: TextStyle(fontSize: 13, height: 1.0)` (13px line box) and
  the default `GutterStyle`, every gutter row's top is on the code line grid
  (pitch equals the rendered line height, drift 0 at the last row).
- The same holds for `fontSize` 9 through 15 — the whole sub-16 range, since
  the overshoot is a function of how much shorter than 16 the line is.
- The issue icon and the fold-toggle chevron are both clamped to the line
  height.
- Above a 16px line box the icons still render at 16 — the gutter's
  geometry and the code's start offset are unchanged.
- Turning the icons off entirely keeps the numbers on the grid (the existing
  ablation: `delta` 0 at every font size today).

## Non-goals

- `GutterStyle.padding` (fork #6) and the `height` copy in `_buildGutter()`
  (upstream #262 / fork #28) — both already landed and pinned.
- Wrap-mode `rowHeights`, separately measured.
- Changing `_issueColumnWidth` / `_foldingColumnWidth`, which set the gutter's
  geometry.
