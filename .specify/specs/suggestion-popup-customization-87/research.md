# Research: suggestion-popup-customization (#87)

## The premise, checked against the tree

The synced upstream issue (#211) lists four complaints. Before writing any
code I checked each against this fork. Two are wrong today and one is already
answered; recording which, because the issue reads as if all four are open.

### R1 — "Box is flipped if in the bottom there's not enough space for max
suggestion box height not the actual needed height" — ALREADY ANSWERED

`lib/src/wip/autocomplete/popup.dart:72-74`:

```dart
final neededHeight = _neededPopupHeight(context);
final verticalFlipRequired =
    widget.normalOffset.dy + neededHeight > windowSize.height;
```

`_neededPopupHeight` (line 145) is `min(suggestions.length * _rowHeight,
Sizes.autocompletePopupMaxHeight)` — the height the rows actually need, capped
at the maximum. The flip is decided on the capped needed height, never on the
maximum alone.

`_rowHeight` (line 164) is the subtle part: it measures with
`Theme.of(context).textTheme.bodyMedium?.merge(widget.style)`, because every
row's `Text` renders one level below a `Material`, which installs `bodyMedium`
as the ambient default. Measuring the popup's own `DefaultTextStyle` instead
misses whenever the two differ, and the row-height error moves both the flip
decision and the unflipped clamp. Commit history for #84 attributes the
original defect to exactly this.

### R2 — "Positioning is not covered by tests" — ALREADY ANSWERED

`test/src/wip/autocomplete/popup_placement_test.dart`, 8 widget tests, pumps
the bare `Popup` in a `Stack` with the geometry the field would hand it:

- horizontal clamp, caret past the popup width (SC-003)
- horizontal follows the caret when there is room (SC-003)
- vertical flip near the window bottom (SC-004)
- room below keeps the popup below the caret (SC-004)
- a single suggestion just above the bottom flips (SC-004)
- many suggestions measured at the capped height (SC-004)
- a window narrower than the popup clamps to the left edge
- an empty suggestion list still builds

Plus `popup_test.dart` (rendering, tap commits, focus return) and
`popup_controller_test.dart` (state, scrolling, arrow navigation).

### R3 — "The widget cannot be customized" — OPEN, and the only open one

`Popup._buildListItem` (`popup.dart:175-202`) builds the row inline. The only
host-reachable knobs are `CodeField.autocompleteBackground`
(`code_field.dart:217`, resolved at `:557`) and the field's `textStyle`.
Neither reaches the row's structure: the `Material` tint, the selected-row
`ColoredBox`, the `InkWell`, or the `Text`'s overflow.

Crucially, `Popup` and `PopupController` are **not exported** from
`lib/zuraffa_code_editor.dart` — the barrel stops at `src/line_numbers`,
`src/named_sections` and `src/folding`, with no `src/wip/autocomplete` entry.
A host therefore cannot even name the types to rebuild a row from outside the
package. That constraint decides the hook's signature: the builder must be
handed the suggestion text, because it cannot read it off the controller.

### R4 — "CodeController is aware of them by owning PopupController and
commanding it" — TAKEN AS DOCUMENT-AND-PIN

Call sites in `lib/src/code_field/code_controller.dart`:

| Line | Call |
| ---- | ---- |
| 128 | `late PopupController popupController` — the field |
| 244 | constructed with `onCompletionSelected: insertSelectedWord` |
| 475-482 | `scrollByArrow` on arrow keys |
| 494-495 | `insertSelectedWord` on enter |
| 521-522 | `insertSelectedWord` on tab |
| 537, 571 | `hide` after insertion |
| 710 | `hide` on IME composition end |
| 812 | `hide` on selection change |
| 1116, 1125, 1127 | `show`/`hide` in `generateSuggestions` |
| 1310-1311 | `enabled` gate in `_dismissSuggestions` |

These are one direction: the controller drives a view of state it owns. The
upstream complaint was written when the popup was newly inherited and the
coupling was undocumented; the issue itself offers the alternative "or the
coupling is documented and pinned". Splitting it would introduce an interface
that forwards the same calls — no decision moves, and the popup's visibility
becomes refactor risk with no defect to justify it.

**What is actually missing is that the contract is written down.** Hence
T008: document the field, name the call sites, pin the observable sequence.

## What this means for the spec

Only R3 needs code. R1 and R2 are satisfied and pinned — the PR will say so
rather than re-implementing them. R4 is satisfied by documentation plus a pin,
which is the issue's own second option.
