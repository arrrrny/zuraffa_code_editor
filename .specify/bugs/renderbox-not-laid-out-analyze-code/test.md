# Bug Test Report: RenderBox was not laid out when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Issue**: 32
- **Result**: pass

## TDD cycle

1. **RED** — `test/src/code_field/code_field_notify_before_layout_test.dart`
   written first, pumping a `CodeField` whose sibling calls
   `controller.notifyListeners()` from `performLayout()`. On master
   (`git stash` of the fix) both tests fail with
   `RenderBox was not laid out: RenderFractionalTranslation#… NEEDS-LAYOUT
   NEEDS-PAINT … Failed assertion: 'hasSize'`.
2. **GREEN** — `_isEditorBoxLaidOut` guard added to `_onTextChanged` and
   `_updatePopupOffset`; both tests pass, full suite 352/352.

## Coverage of the fix

- `A controller notification landing while the frame is still laying out does
  not assert` — the pinned window: the notification reaches `_onTextChanged`
  and `_updatePopupOffset` while the editor box has no size, and no exception
  is reported.
- `The deferred part of the mid-frame notification still applies` — the same
  notification is not lost: a following frame reads the now laid-out editor box
  without asserting, so the popup offset update still happens.

## Honest caveat

- The *reported* symptom — a red console on a plain first layout with nothing
  but a `CodeController` + `CodeField` — does **not** reproduce on current
  master (verified: `createApp` + `pumpWidget` + `pump(100ms)` is clean). The
  regression test therefore pins the unguarded code path that upstream's stack
  trace names, by forcing the same window with a layout-phase notification,
  rather than pinning the report's literal repro.
- The test uses `GutterStyle.none` on purpose. With the gutter present,
  `GutterWidget`'s `AnimatedBuilder` answers the same mid-frame notification
  with `setState` and throws `Build scheduled during frame` — on master too,
  independent of this fix. That is a second pre-existing defect in the same
  family and is recorded as out of scope in `assessment.md`.
- Flutter version skew: upstream reported on 3.22.2; this fork and its CI run
  3.47.5, where the frame timing of `unawaited(analyzeCode())` differs. The
  unguarded `localToGlobal` on an unlaid-out box is version-independent (it is
  a plain `hasSize` assertion in `RenderBox.transform`), so the pinned path
  holds either way.
