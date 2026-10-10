# Test list: auto-scroll-caret

| # | Test | Type |
|---|---|---|
| 1 | vertical scroll follows the caret while typing — 40 typed lines in a 200px field move the EditableText's Scrollable offset above 0 | widget (red on master: RenderFlex overflow 792px; green with fix) |

No unit-test seam was needed: the defect is layout/scrolling behaviour, only
observable through the real widget tree.
