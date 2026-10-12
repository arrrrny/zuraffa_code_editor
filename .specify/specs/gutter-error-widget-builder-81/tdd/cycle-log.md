# Cycle Log: gutter-error-widget-builder-81

Engine: raw (`.specify/memory/tdd-profile.md`). One behavior at a time:
red proven → smallest change → green → tick.

## Baseline — 2026-10-12

- Suite: `flutter test` on `spec/gutter-error-widget-builder-81` @ `77a451b`
  (master `0a31d8e` + spec/plan/tasks commits).
- Test list written: 7 behaviors (A1–A5 acceptance, U1–U2 unit).
- Behaviors DONE: 0/7.

## Loop — 2026-10-12

- **Red (T1)**: `test/src/gutter/gutter_error_widget_builder_test.dart`
  written. `flutter test` fails to compile — `No named parameter with the
  name 'errorPopupBuilder'` at `GutterStyle`. Red for the right reason (the
  API does not exist).
- **Green (T2–T4)**: `errorPopupBuilder` field + import + constructor +
  `copyWith` relay in `gutter_style.dart`; `_fillIssues` in `gutter.dart`
  resolves the popup text style once per issue (throw semantics unchanged)
  and takes `style.errorPopupBuilder?.call(...) ?? GutterErrorWidget(...)`.
- `flutter test test/src/gutter/gutter_error_widget_builder_test.dart`:
  **+6 All tests passed**.
  - A1/A2 — builder receives `(issue, _popupStyle, decoration)` and its
    widget replaces `GutterErrorWidget` (findsNothing on the built-in).
  - A3 — default mounts `GutterErrorWidget` with `defaultIssueIcon`,
    `Colors.red`, null decoration (characterization).
  - A4 — null text style still throws
    'Error popup style should never be null' with a builder set.
  - per-issue — builder invoked once per issue, two sentinels mounted.
  - U1/U2 — `copyWith` relay incl. explicit-null keeping the builder.
- Behaviors DONE: 7/7 (A1–A5, U1–U2). Tasks T1–T4 ticked.

