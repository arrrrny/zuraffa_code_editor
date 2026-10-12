# TDD verification: suggestion-popup-customization

Feature: `.specify/specs/suggestion-popup-customization-87`
Branch: `spec/suggestion-popup-customization-87`

## Test list

`test/src/wip/autocomplete/popup_item_builder_test.dart` — 9 widget tests,
written before the field existed. The ninth was added in response to pool
review of #140; see `## Pool review of #140` below.

| # | Test | Guards |
| - | ---- | ---- |
| 1 | no builder: the built-in row is the one that renders | default path, row tint |
| 2 | the selected row carries the selection tint | the tint my refactor could have dropped |
| 3 | a builder replaces the row for every suggestion | dispatch, and that the built-in chain is gone |
| 4 | isSelected follows selectedIndex | selection state is handed to the host |
| 5 | onSelect commits the right suggestion and returns focus | the commit path |
| 6 | a builder that ignores isSelected still commits correctly | the contract does not depend on the host reading state |
| 7 | show resets the selection to the first row | the observable sequence a host relies on |
| 8 | hide clears shouldShow and notifies | the other half of that sequence |
| 9 | a host row gets a `Material` ancestor of its own | the wrapper review of #140 found missing |

Tests 1–8 were written before `CodeField.suggestionItemBuilder` and
`Popup.suggestionItemBuilder` existed and run RED.

`test/src/code_field/suggestion_item_builder_test.dart` — 2 more, added after,
for the half the direct-pump tests cannot reach: that `CodeField` actually
hands the builder to the popup it builds for its overlay. The shape follows
`autocomplete_popup_background_test.dart`, which pins the sibling parameter the
same way.

| # | Test | Guards |
| - | ---- | ---- |
| 9 | a builder set on the field reaches the popup rows | the wiring |
| 10 | no builder renders the built-in row through the field | the default path, end to end |

## RED evidence

First RED run (`flutter test --concurrency=2
test/src/wip/autocomplete/popup_item_builder_test.dart`):

```text
test/.../popup_item_builder_test.dart:54:19: Error: No named parameter with
  the name 'suggestionItemBuilder'.
                    suggestionItemBuilder: itemBuilder,
lib/src/wip/autocomplete/popup.dart:36:9: Context: Found this candidate, but
  the arguments don't match.
00:00 +0 -1: Some tests failed.
```

That is the whole RED: one error, and it is the one the feature removes.

Three intermediate RED runs were red for reasons in the **test**, and each was
corrected rather than deleted — all three are worth recording, because two of
them were the test asserting the wrong thing about the widget it was pinning:

- `Color get selectedTint => ...` — a getter cannot be declared inside
  `main()`. Changed to a local function.
- `Bad state: Too many elements` from `wt.widget<ColoredBox>` —
  `find.ancestor(matching: ColoredBox)` matched more than one box above the
  text, because the row's `Material(color: …)` also renders one. The helper was
  split in two, one per tint, each anchored to the widget that actually owns
  it.
- `Expected: alpha 0.1000, Actual: alpha 0.1020` — `withValues(alpha: 0.1)` is
  full precision while the widget used the deprecated `withOpacity(0.1)`,
  which rounds to 8 bits. Fixed on the **widget** side: `popup.dart` now uses
  `withValues`, which also retires a deprecated call in code this branch
  rewrites anyway.

## GREEN evidence

```text
flutter test --concurrency=2 test/src/wip/autocomplete/   →  All tests passed! (30)
```

30 = the 9 new tests plus the 21 already in `popup_test.dart`,
`popup_controller_test.dart` and `popup_placement_test.dart`, all of which pass
**unmodified**. That is the regression net for the claim that placement, flip
and clamping are untouched.

Re-run after the #140 review fixes: still 30, and
`test/src/code_field/suggestion_item_builder_test.dart` still 2. `dart analyze
--fatal-infos` silent, `dart format --output=none --set-exit-if-changed .`
clean (306 files, 0 changed).

## Pool review of #140

`zuraffa-review[bot]` returned **COMMENTED / near-merge**, one 🟠 actionable
finding, one 🟡 and one 🔵 nit. Both findings were addressed on this branch
rather than deferred, because both are about the shape this feature ships.

**🟠 Host rows had no `Material` ancestor.** The built-in row wraps its
`InkWell` in a `Material`, and my dispatch handed a host's widget straight back
with nothing around it — so the `ListTile` this feature's own doc example
advertises would have been without a `Material` ancestor and asserts in debug.
`_buildListItem` now wraps the builder's return value in `Material(type:
MaterialType.transparency)`, which paints nothing, so the host's surface and the
popup's `backgroundColor` are unchanged. It also keeps a host row one level below
a `Material`, which is the ambient `bodyMedium` `DefaultTextStyle` that
`_rowHeight` measures against — so the fix helps the placement math as well as
the `ListTile`.

**Test 9** pins it, and the assertion is deliberately about the **nearest**
ancestor and its type rather than about existence. Existence is a tautology
here: `pumpPopup` sits inside a `Scaffold`, which has a `Material` of its own,
so "a `Material` exists above the row" passes with the wrapper removed. What
does not pass is the type. Verified by removing the wrapper and watching the
assertion flip:

```text
Expected: MaterialType:<MaterialType.transparency>
  Actual:   MaterialType:<MaterialType.canvas>      ← the Scaffold's own
```

The wrapper was then restored and the file confirmed byte-identical before
committing.

**🟡 The flip and clamp measure the built-in one-line row only.** A builder
returning a taller row is laid out at its own height, so a list of them can be
taller than the space the flip reserved. This is a real limit of measuring a
single row, and it is now documented rather than left for a host to discover:
on `CodeField.suggestionItemBuilder`, with its consequences spelled out, and
referenced from `Popup.suggestionItemBuilder` so the two copies cannot drift.

The 🔵 nit about the duplicated doc paragraph was closed by that same
reference — one place to read it, not two copies to keep in step.

## Mutation audit

### M-ignorebuilder — killed

`_buildListItem` ignoring the builder and always running the built-in chain.
Test 3 fails on `expect(seen, suggestions)` (the builder is never called) and
on `expect(find.byType(InkWell), findsNothing)`. Test 4 fails on
`expect(selected, ['alpha'])`.

### M-dropcommit — killed

`_commitAt` dropping `parentFocusNode.requestFocus()`. Test 5 fails on
`expect(focusNode.hasFocus, isTrue, reason: 'focus must return to the editor')`,
and test 6 fails the same way. This is the half a host would otherwise drop,
which is why the callback is passed in rather than reached for.

### M-dropselect — killed

`_commitAt` dropping `selectedIndex = index`. Test 5 fails on
`expect(controller.selectedIndex, 2)` and test 6 on
`expect(controller.selectedIndex, 1)`.

### M-alwaystint — equivalent (documented, not counted)

Making the built-in row always paint the selection tint fails tests 2 and 1 —
but so would *any* change to the tint, including a correct one, because the
colour is an inline literal in the widget and the test reproduces it. The tint
is not the contract; that a host row replaces the chain is. Recorded rather
than counted, for the same reason the #86 audit recorded `M-wrongwidth`.

## Coverage

CI-identical gate, run on the committed tip. See `Gates` below.

## Static gates

```text
dart analyze --fatal-infos                          →  No issues found!
dart format --output=none --set-exit-if-changed .   →  clean
```

Note: `analysis_options.yaml` excludes `lib/src/wip` from analysis, so
`popup.dart` is not linted — the reason its `withOpacity` calls had survived
until this branch. `test/` is **not** excluded, which is why the new test uses
`withValues`.
