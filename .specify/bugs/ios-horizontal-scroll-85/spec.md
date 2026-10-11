# Spec: ios-horizontal-scroll-85

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/85
(upstream akvelon/flutter-code-editor#280).

## Verdict

**Not reproducible as filed.** The reported platform split is inverted: on master
the code area scrolls horizontally on drag under an iOS platform override and does
not under an android one, and the split comes from Flutter, not from this package
(see `assessment.md` for the measurements and the `text_selection.dart:3731`
mechanism). The caret reveal already works on every platform.

What *is* missing — and all this change ships — is the regression pin the issue's
own acceptance criterion 3 asks for. No behaviour change is part of this PR.

## Requirement (what must stay true)

The geometry and scroll offsets that make the difference must be pinned so a
future change to `_wrapInScrollView`, `_horizontalCodeScroll`, or the field's
`TextField` cannot silently break horizontal scrolling.

## Acceptance

- A drag over the code text scrolls `_horizontalCodeScroll` when the platform is
  iOS — pinned with the measured offset.
- The same drag does not scroll it when the platform is android — pinned, so the
  Flutter platform split is visible in the suite rather than implied.
- The caret is revealed horizontally by `End`, `Home` and `→` on the focused field.
- `wrap: true` leaves the code area with no horizontal scroll view at all, and the
  behaviour pins stay inert.
- Content that fits the viewport (`maxScrollExtent == 0`) is not scrolled.
- No platform branch anywhere in `lib/`; nothing in the package changes.
- No regression: full suite green, `dart analyze` clean, `dart format` clean,
  coverage gate at 100%.

## Non-goals

- Making a drag over the code text scroll on non-Apple platforms. Flutter's
  gesture arena, not this package; the only lever removes text selection.
- An interactive horizontal `Scrollbar` (the documented follow-up in
  `assessment.md`). Material's `ScrollBehavior.getScrollbars` hides it on
  Android/iOS, so it needs a `showScrollbar` or platform decision of its own.
- Any change to `_wrapInScrollView`'s widget structure, the `TextField`'s
  `enableInteractiveSelection`, or `_horizontalCodeScroll`.

## Tests

`test/src/code_field/horizontal_scroll_behaviour_test.dart`.
