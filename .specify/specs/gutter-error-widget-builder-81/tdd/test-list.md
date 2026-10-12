# Test List: gutter-error-widget-builder-81

Derived: 2026-10-12 · Engine: raw (see `.specify/memory/tdd-profile.md`)
Spec: ./spec.md · Plan: ./plan.md

## Acceptance behaviors (from spec acceptance criteria)

- [x] A1 — The gutter calls `GutterStyle.errorPopupBuilder` with the issue, the
      resolved popup `TextStyle`, and the resolved `BoxDecoration?`, when the
      style sets it. (AC: "gutter calls the builder per issue")
      Traces to: AC-1 widget mount, `test/src/line_numbers/gutter_error_widget_builder_test.dart`
- [x] A2 — The gutter mounts the widget the builder returns in place of
      `GutterErrorWidget`. (AC: "builder's widget is mounted")
- [x] A3 — A style that sets no builder renders the same `GutterErrorWidget`
      with the same icon, text style and decoration as before the change
      (characterization; default unchanged). (AC: "renders identically")
- [x] A4 — The builder receives the style's `errorPopupTextStyle`; a null text
      style still throws the same exception even with a builder set. (AC:
      "same exception")
- [x] A5 — `GutterStyle.copyWith` carries `errorPopupBuilder`; an explicit null
      argument keeps the existing builder (relay semantics). (AC: "copyWith
      carries the new field")

## Unit behaviors (from functional requirements)

- [x] U1 — `GutterStyle` accepts `errorPopupBuilder` in its constructor as
      `Widget Function(Issue, TextStyle, BoxDecoration?)?` and defaults it to
      null. (FR: constructor acceptance)
- [x] U2 — `copyWith(errorPopupBuilder: f)` replaces the builder;
      `copyWith()` without the argument keeps it. (FR: relay; merged into A5's
      test file as a pure unit test, no widget)

## Coverage obligations

- `lib/src/gutter/gutter.dart`: both arms of the new `??` — A1/A2 (builder
  arm) and A3 (default arm). A4 covers the throw.
- `lib/src/line_numbers/gutter_style.dart`: U1/U2 cover the field, the
  constructor default and the copyWith relay branch.
- The gate is 100% line coverage (`tool/coverage_gate.py --min 100`); the
  `EXEMPT_LINES` line numbers shift if lines are inserted above an exempted
  line in either file — renumber after the edit, before running the gate.

## Cycle log

See `tdd/cycle-log.md`.
