# Data model: highlight-cursor-line

No new types. The spec adds one field and one derived value; everything else it
touches already exists and is unchanged.

## New state

| Name | Type | Owner | Default | Notes |
|---|---|---|---|---|
| `currentLineColor` | `Color?` | `CodeController` | `null` | Read during render, not stored in the span tree. Null means no caret tint. |

## New derived value

| Name | Type | Where computed | Domain |
|---|---|---|---|
| `currentLineIndex` | `int` | `LineBackgroundLayer.build` | `-1` when there is no caret in range, otherwise the caret's line index |

`-1` is used as the "none" sentinel because it can never equal a value in
`hiddenLineRanges.visibleLineNumbers`, so the downstream comparison needs no
branch. It is not persisted and not exposed.

## Existing entities this depends on

| Entity | File | Role |
|---|---|---|
| `CodeController` | `lib/src/code_field/code_controller.dart` | Owns `currentLineColor`, `lineBackgroundBuilder`, `selection`, `code`. Extends `TextEditingController`, so it notifies on selection-only changes — this is what makes the tint follow the caret without a new listener. |
| `Code` | `lib/src/code/code.dart` | `code.text` is the buffer the offset is range-checked against; `code.lines` is what the conversion searches. |
| `CodeLines.characterIndexToLineIndex` | `lib/src/code/code_lines.dart:30` | Character offset → 0-based line index. Throws `RangeError` outside `[0, text.length]`, hence the guard. |
| `CodeLine.textRange` | `lib/src/code/code_line.dart` | The ranges the binary search walks. |
| `HiddenLineRanges.visibleLineNumbers` | `lib/src/hidden_ranges/hidden_ranges.dart` | The line indices actually rendered — the domain `currentLineIndex` is compared against. |
| `LineBackgroundLayer` | `lib/src/code_field/line_background.dart` | Resolves each visible row's colour; the only widget that changes. |
| `CodeField.build` | `lib/src/code_field/code_field.dart` | Widens the layer's gate conjunctively; no other change. |

## Coordinate spaces

Two, and they must not be conflated — this is the exact mistake the corrected doc
example made.

| Space | Values | Produced by |
|---|---|---|
| Character offset | `0 … code.text.length` | `selection.extentOffset` |
| Line index | `0 … code.lines.length - 1` | `characterIndexToLineIndex(offset)`, and `lineBackgroundBuilder`'s argument |

`currentLineColor` lives in neither: it is a paint input, applied to whichever
line index the caret resolves to.

## State transitions

| Transition | Effect on the tint |
|---|---|
| Caret moves within the text | Tint follows to the new caret line |
| Caret moves by keystroke | Same, via `CodeController` notifying → `_onTextChanged` → `rebuild()` |
| Text edited | Caret moves (Flutter updates the selection) → tint follows; row heights change, recomputed by `_visibleRowHeights` |
| A fold opens over the caret's line | Line no longer rendered → no tint |
| A hidden section collapses over the caret's line | Line no longer rendered → no tint |
| `lineBackgroundBuilder` set / reassigned | Host colours win on the lines they colour; caret tint fills the rest |
| `currentLineColor` set to null | Caret tint stops; the layer stays if the builder is set |
| Both set to null | Layer and `Stack` leave the tree entirely |

## Edge cases and their expected outcome

| Case | `extentOffset` | Outcome |
|---|---|---|
| Empty document, no interaction | `-1` | No tint, no crash |
| Caret on the first line | `0` | Line 0 tinted |
| Caret at the very end of the text | `text.length` | Last line tinted (documented as valid for the helper) |
| Caret mid-line | inside that line's `textRange` | That line tinted |
| Selection spanning lines 2–5 | on line 5 (extent) | Only line 5 tinted |
| Caret inside a folded block | valid offset, line not visible | No tint — no row to paint |
| `code` one frame behind the value | `> code.text.length` | No tint that frame, tint on the next |
