# Tasks: gutter error popup builder

**Spec:** ./spec.md · **Plan:** ./plan.md · **Test list:** ./test-list.md

## Phase 1 — the test file (red)

- [x] T1 `test/src/line_numbers/gutter_error_widget_builder_test.dart`: the
      tests below. Red on the old base because `GutterStyle` has no
      `errorPopupBuilder` and the file does not compile.

## Phase 2 — the field (behaviour)

- [x] T2 `lib/src/line_numbers/gutter_style.dart`: `errorPopupBuilder` field —
      `Widget Function(Issue, TextStyle, BoxDecoration?)?` — plus the
      `../analyzer/models/issue.dart` import and its doc comment.
- [x] T3 `lib/src/line_numbers/gutter_style.dart`: `copyWith` parameter and
      relay, matching the sibling fields.

## Phase 3 — the call site (behaviour)

- [x] T4 `lib/src/gutter/gutter.dart` `_fillIssues`: resolve the popup text
      style once, call the builder when set, otherwise construct
      `GutterErrorWidget` as today.

## Phase 4 — records

- [ ] T5 `CHANGELOG.md`: entry under the current release, naming fork issue #81
      and the upstream `akvelon/flutter-code-editor#216` ask, stating the
      default is unchanged.
- [ ] T6 `README.md` / doc mention if the `GutterStyle` fields are documented
      there (check `gutter_error_icon_override` PR #96 for where icon
      overrides were documented; mirror that location).
- [ ] T7 Coverage gate: `flutter test --coverage` +
      `python3 tool/coverage_gate.py --min 100`, cleaning the helper test and
      `coverage/` afterwards. Renumber `EXEMPT_LINES` in
      `tool/coverage_gate.py` if the inserted lines shifted an exempted line.

## Dependencies

- T1 alone is red; T2+T3 make the constructor/reference tests compile; T4 takes
  the widget-mount tests green. T5–T7 are records, independent of each other.

## Test inventory (for T1)

1. **Default renders `GutterErrorWidget`** — gutter mounted with a style that
   sets nothing; the issue column child is a `GutterErrorWidget` whose icon,
   popup text style and decoration match today's resolution.
2. **Builder is called with the resolved triple** — style sets
   `errorPopupBuilder`; the builder receives the issue, the style's
   `errorPopupTextStyle`, and the style's `errorPopupDecoration`.
3. **Builder's widget is mounted** — builder returns a sentinel widget; the
   issue column renders the sentinel, not `GutterErrorWidget`.
4. **Null text style still throws under a builder** — builder set,
   `errorPopupTextStyle` null; the same exception as today.
5. **`copyWith` carries the builder** — unit test, no widget mount.
6. **`copyWith(null)` keeps the existing builder** — same relay semantics as
   the sibling fields.

## Parallelism

T2 and T3 are the same file (sequential); T4 depends on T2 existing; T5–T7 are
independent once T4 is done.
