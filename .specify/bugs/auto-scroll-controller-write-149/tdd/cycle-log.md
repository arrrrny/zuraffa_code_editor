# Cycle log: auto-scroll-controller-write-149

## Red

`test/src/code_field/programmatic_write_reveals_caret_test.dart` written
against master `647e9be` (no fix applied):

```
Expected: a value greater than <0>
  Actual: <0.0>
   Which: is not a value greater than <0>
a write that walks the caret past the bottom of the viewport must reveal it
```

`pixels == 0.0` while `maxScrollExtent == 816.0`: the extent exists, nothing
scrolls to it. Two control probes (real `enterText` typing, and the same at
80 ms/line with the analysis debounce firing) scroll 0 → 816 and 0 → 456
respectively, so the gap is the controller path, not the layout or the
debounce. All three probes were deleted before the commit.

## Green

Fix in `lib/src/code_field/code_field.dart`:

- `_lastValue` + a comparison at the top of `_onTextChanged`, so only a value
  change (not an analysis/search/popup notification) asks for a reveal.
- `_revealCaretOnScreen`, scheduled post-frame: focus gate, validity gate,
  `_renderEditable`/`_codePosition` gate, an
  `allowImplicitScrolling` gate, then
  `position.jumpTo(_offsetToRevealCaret(...))` followed by
  `renderEditable.showOnScreen(...)`.
- `_offsetToRevealCaret`: the caret rect from
  `getLocalRectForCaret` is relative to the visible band, so the reveal is the
  smallest delta that puts it inside `[0, viewportDimension]`, clamped to the
  scroll extents.
- `_renderEditable` / `_findRenderEditable`: the editor box is searched for
  the field's single `RenderEditable`, because `EditableText` builds it below
  proxies no key in this package reaches.

First attempt drove `renderEditable.showOnScreen` alone and did not scroll —
the probe showed the parent chain carries no vertical viewport, because
`RenderEditable` is its own (`offset` is passed into it and the text is
painted shifted by `offset.pixels`). That is what moved the fix onto the
position itself.

## Refactor

- The caret rect is read once and used for both halves of the reveal, the same
  order the framework makes them in.
- `min(max(target, min), max)` keeps the clamp to three lines with no
  untaken branch, so the gate stays honest without a second test.
