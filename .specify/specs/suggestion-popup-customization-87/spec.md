# Spec: suggestion-popup-customization

Fork issue: #87 · Upstream: akvelon/flutter-code-editor#211
Label: `spec` · Severity: `medium`

## What was asked

"The current problems with suggestions: `CodeController` is aware of them by
owning `PopupController` and commanding it. They are generally poorly designed
because we did not clean them up when got ownership. The widget cannot be
customized. Box is flipped if in the bottom there's not enough space for max
suggestion box height not the actual needed height. Positioning is not covered
by tests."

## What exists today

Three of the four complaints are already answered on this fork, and this spec
does not reopen them:

- **The flip uses the height actually needed.** `Popup.build`
  (`lib/src/wip/autocomplete/popup.dart:72-74`) decides the flip on
  `_neededPopupHeight(context)` — one measured row per suggestion, capped at
  `Sizes.autocompletePopupMaxHeight` — not on the maximum. `_rowHeight`
  (line 164) measures with the ambient `bodyMedium` style merged with the
  popup's own, so the flip decision and the unflipped clamp agree with what the
  rows actually render at.
- **Positioning is covered by tests.**
  `test/src/wip/autocomplete/popup_placement_test.dart` pins horizontal
  clamping (SC-003), the vertical flip and the unflipped placement (SC-004),
  the capped-height case, a window narrower than the popup, and an empty list.
  Those tests were written for the earlier cutoff defect (fork #84) and are
  the reason the flip is now measured on the needed height.
- **The row's own theming is partly reachable.** `CodeField` accepts
  `autocompleteBackground`, resolved into `_popupBackground`
  (`code_field.dart:557`) and handed to the popup; the row's text style comes
  from the field's `textStyle`.

What is still frozen: **the row widget itself.**
`Popup._buildListItem` (`popup.dart:175-202`) constructs the row inline — a
`Material` at `grey.withOpacity(0.1)`, an `InkWell`, a `ColoredBox` that paints
`blueAccent.withOpacity(0.5)` over the selected row, and a `Text` with
`TextOverflow.ellipsis`. A host that wants an icon per suggestion, a
two-line row, a different selection affordance, or its own enter/exit
animation must subclass or fork the package. `Popup` and `PopupController`
are not exported from the barrel, so the host cannot even reference them to
rebuild the row from outside.

This is the umbrella for the autocomplete defects filed separately — #90
(suggestion icons) and the remainder of the upstream #205 family are all
downstream of "the row cannot be replaced".

## What this spec adds

One nullable field on `CodeField`, beside `autocompleteBackground`:

```dart
final Widget Function(
  BuildContext context,
  String suggestion,
  bool isSelected,
  VoidCallback onSelect,
)? suggestionItemBuilder;
```

When set, `Popup` calls it per row instead of running `_buildListItem`,
handing it the same four things the built-in row acts on. When null the popup
runs `_buildListItem` exactly as it does today, with the same widgets, the same
colours and the same arguments — the default tree is unchanged.

## Decisions

- **The default does not change.** With the field null, `Popup` builds the
  identical `Material` → `InkWell` → `ColoredBox` → `Padding` → `Text` chain.
  The feature is additive and opt-in, exactly as `GutterStyle.errorPopupBuilder`
  was in #81.
- **The hook is a row builder, not a whole-popup builder.** The popup's
  value is its placement — the clamp and flip this fork already pins in
  `popup_placement_test.dart`. A whole-popup builder would hand that back to
  every host and invite the cutoff defect (#84) to return. A row builder keeps
  placement in the package and gives the host the part that is actually
  frozen: what a suggestion looks like.
- **The builder receives the data, not the controller.** `PopupController` is
  not exported from the barrel, so a host cannot read
  `controller.suggestions[index]` from a builder. Passing the text makes the
  hook usable without widening the public API to a `wip` type, and keeps the
  signature honest about what the built-in row is given.
- **`onSelect` is the commit path, not a re-implementation of it.** The
  built-in row does two things on tap: set `selectedIndex` and request focus
  back on the editor, then call `onCompletionSelected`. The builder's callback
  performs that same sequence, so a host that ignores `isSelected` and paints
  its own selected state still gets correct commit behaviour. It is passed in
  rather than reached for, because the focus return is part of the contract a
  host would otherwise silently drop.
- **The coupling is documented and pinned, not removed.** Reached only by the
  issue's own alternative ("or the coupling is documented and pinned"). The
  `CodeController` → `PopupController` calls — `show`/`hide` from
  `generateSuggestions`, `hide` on selection change and IME end,
  `scrollByArrow` on arrow keys, `insertSelectedWord` on enter/tab, `enabled`
  in `_dismissSuggestions` — are the controller driving a view of state it
  owns. Splitting them would move the same commands behind an interface
  without removing a single decision, and would put the popup's visibility at
  risk during a refactor this spec has no defect to justify. What is missing
  is that the contract is written down, so: the field on `CodeController` gains
  a doc comment naming every call site, and `popup_controller_test.dart` gains
  a pin that the public sequence a host can observe — `show` resets the
  selection to 0, `hide` clears `shouldShow` — holds.

## Out of scope

- Changing `Popup`'s placement, clamp, flip or measurement (already correct and
  pinned).
- Exporting `Popup` or `PopupController` from the barrel — that is a separate
  API decision about a `wip` module, not something this feature needs.
- Re-skinning the built-in row's colours: `autocompleteBackground` and
  `textStyle` already reach it, and #81's `errorPopupBuilder` precedent
  deliberately kept the built-in widget's own constructor alone.
- Retiring `PopupController`'s mutable public fields (`shouldShow`, `enabled`,
  `suggestions`). They are pre-existing API; narrowing them is its own change.

## Acceptance criteria

- [ ] `CodeField` accepts `suggestionItemBuilder`, nullable, typed as above.
- [ ] The popup calls the builder once per row when it is set, passing the
      suggestion's text, whether that row is selected, and a callback that
      commits it exactly as the built-in row does.
- [ ] The popup renders the built-in row, widget for widget, when the builder
      is null.
- [ ] A field that sets no builder renders identically to before this change.
- [ ] A builder that paints its own selected state still commits the right
      suggestion and returns focus to the editor.
- [ ] The `CodeController` → `PopupController` contract is documented at the
      field and pinned by a test.
- [ ] A host row is built inside a `Material(type: MaterialType.transparency)`
      ancestor, so the `ListTile` shape the hook advertises is legal and a
      host row's own text still renders at the height the flip was measured
      at.
- [ ] The row height is documented as beyond the hook's reach: the popup
      measures each suggestion as the built-in single line, and a taller row
      can overflow the space the flip reserved.
- [ ] Flip-on-needed-height and the placement tests are named in the PR as the
      criteria they already satisfy, not re-implemented.
- [ ] Coverage stays at the 100% gate; new branches are covered or proved dead.

## Pool review of #140

Two findings came back from `zuraffa-review[bot]` and are folded into the
criteria above rather than deferred:

- **🟠 actionable** — host rows had no `Material` ancestor, so the documented
  `ListTile` example would assert in debug. Fixed by wrapping the builder branch,
  and pinned by a test that checks the **nearest** `Material` above the row is
  the transparency one. That distinction is the whole test: without the wrapper
  the nearest `Material` is the surrounding `Scaffold`'s, and the assertion
  would read `MaterialType.canvas` — verified by removing the wrapper and
  watching exactly that happen.
- **🟡** — the flip and clamp measure the built-in one-line row only, so an
  advertised "second line" could overflow. Documented on both
  `CodeField.suggestionItemBuilder` and `Popup.suggestionItemBuilder`, with the
  latter pointing at the former so there is one place to read it.

The 🟡 nit about the doc paragraph being duplicated verbatim on both widgets was
resolved the same way — by making the `Popup` copy reference the `CodeField`
one rather than repeat it.

## Gates

`flutter test` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
