# TDD Cycle Log: mounted-disposed-checks

## 2026-10-09 — baseline

- Feature: .specify/bugs/mounted-disposed-checks (spec: ./spec.md)
- Stack: raw flutter (`flutter test`), profile: .specify/memory/tdd-profile.md
- Test list: ./tdd/test-list.md — 3 outer behaviors (B1, B2, B3) + 1 guard (G1)
- Entry condition: fix branch `fix/mounted-disposed-checks` at master 9125691,
  295 tests green.
- Next: write B1/B2 tests, prove RED, apply the two guards, prove GREEN.

## 2026-10-09 — RED then GREEN (fix/mounted-disposed-checks)

- B1 RED (real defect): `test/src/gutter/error_popup_dispose_test.dart` →
  `setState() called after dispose(): _GutterErrorWidgetState`. Re-proved by
  `git stash push lib/src/gutter/error.dart` → the dispose-case test fails again
  with the same exception. Happy-path sub-test green in both runs.
- B1 GREEN after adding `if (!mounted) return;` at the top of the 50ms delayed
  callback in `lib/src/gutter/error.dart:49-59`.
- B2 RED (harness artifact, not a defect): the dispose-case never throws —
  on Flutter 3.47.5 `FocusNode.requestFocus` on a detached node is a silent
  no-op (`_parent == null` short-circuits in `focus_manager.dart`). The test
  failed instead on `A Timer is still pending even after the widget tree was
  disposed.`: the periodic `_hidingTimer` started by `showSearch()`
  (`lib/src/search/controller.dart:60`) is checked by the test binding before
  `addTearDown` runs. Fixed by ending the test body with
  `hideSearch(returnFocusToCodeField: false)` — the convention already used in
  `test/src/search/show_hide_search_test.dart`.
- B2 GREEN after the test fix plus the hardening guard in
  `lib/src/search/controller.dart` (`_disposed` flag, checked after the
  `await Future.delayed(Duration.zero)`).
- G1: `flutter test` → **299 tests, all green** (295 pre-existing + 4 new).
- `dart analyze --fatal-infos` → 24 info-level issues, all pre-existing on
  master (deprecations + `use_key_in_widget_constructors`); zero new findings
  from the two new test files or the guards.
