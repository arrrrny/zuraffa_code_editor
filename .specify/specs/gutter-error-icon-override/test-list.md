# Test list: gutter-error-icon-override

Fork issue: #81 · Spec: `.specify/specs/gutter-error-icon-override/spec.md`

Every test starts red. The order below is the red → green order.

## New file: `test/src/gutter/error_icon_override_test.dart`

### `GutterStyle.issueIcon` — the resolution rule

1. `errorIcon` returns the default `IconData` for all three `IssueType` values
   when the style supplies nothing.
2. `errorIcon` returns the style's `errorIcon` for `IssueType.error`.
3. `errorIcon` returns the style's `infoIcon` for `IssueType.info`, and its
   `warningIcon` for `IssueType.warning` — i.e. each type reads its own field
   and none reads another's.
4. A style that sets only `infoIcon` still resolves `error` and `warning` to the
   default: the fields are independent, not a shared fallback chain.
5. The default `IconData` is the same glyph `errorIcon` renders today, so a bare
   style cannot drift from the constant.

### `GutterStyle.copyWith` carries the new fields

6. `copyWith` keeps the icon fields of the receiver when the call supplies none.
7. `copyWith` replaces a field when the call supplies one, leaving the other two.

### `GutterErrorWidget.icon`

8. Mounting `GutterErrorWidget(issue, style)` with no `icon` renders exactly the
   widget `errorIcon` is — same runtime type, same `IconData`, colour and size.
9. Mounting it with an explicit `icon` renders that widget instead of the
   default.

### The gutter wires the resolved icon through

10. A gutter with an `IssueType.error` and a style supplying
    `errorIcon: Icons.bug_report` renders a bug glyph, not the default.
11. A gutter with an `IssueType.info` and a style supplying only `infoIcon`
    renders that glyph while an `IssueType.error` issue on another line still
    renders the default — proving the widget is resolved per issue type, not
    once per gutter.

## Existing tests that must stay green unchanged

- `test/src/gutter/error_popup_content_test.dart` — constructs
  `GutterErrorWidget(issue, _style)` positionally; the new parameter is optional
  and defaults to today's constant, so these must not need editing.
- `test/src/gutter/error_popup_dispose_test.dart` — same positional
  construction.
- `test/src/gutter/gutter_folding_test.dart` — asserts on
  `findsOneWidget`/`findsNothing` for `GutterErrorWidget`, which is unaffected.

That these need no edit is itself the acceptance criterion for "the default does
not change": if any of them has to be touched, the default moved.

## CHANGELOG

`Unreleased › Added`: `GutterStyle.errorIcon`/`warningIcon`/`infoIcon` and
`GutterErrorWidget.icon` (#81).
