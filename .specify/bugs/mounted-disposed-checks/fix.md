# Fix: Guarded lifecycle continuations (mounted-disposed-checks)

Status: **applied** — branch `fix/mounted-disposed-checks`, base master `9125691`.
Source assessment: ./assessment.md (issue #4, upstream akvelon/flutter-code-editor#299).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/gutter/error.dart` | `if (!mounted) return;` at the top of the 50 ms `Future.delayed` callback in `onExit`, before `setState` |
| `test/src/gutter/error_popup_dispose_test.dart` | **new** — B1 dispose case (RED without the guard) + happy-path popup close |
| `lib/src/search/controller.dart` | `bool _disposed = false;` set at the top of `dispose()`; `_onEnterKeyPressed()` returns before `patternFocusNode.requestFocus()` when disposed |
| `test/src/search/search_enter_dispose_test.dart` | **new** — B2 dispose case + happy-path focus move |

## Deviations from the assessment

1. **B2's crash is not reproducible on current Flutter — the guard is pure
   hardening.** `FocusNode.requestFocus` on a detached node is a silent no-op on
   Flutter 3.47.5 (`_parent == null` short-circuits inside
   `focus_manager.dart`), so the reported "focus request on a disposed node
   throws" no longer manifests. The dispose-case test is kept as a pinned
   regression test: it asserts no exception and no notification, and it fails
   loudly if a future Flutter makes the continuation touch the disposed node
   again. The `_disposed` guard makes that independence explicit rather than
   relying on Flutter internals.
2. **B2's test needed a harness fix before it could be honest.** The first
   failure was `A Timer is still pending even after the widget tree was
   disposed.` — the periodic `_hidingTimer` started by
   `CodeSearchController.showSearch()` (`lib/src/search/controller.dart:60`),
   asserted by the test binding before `addTearDown` runs. Ending the test body
   with `hideSearch(returnFocusToCodeField: false)` (the convention already used
   by `test/src/search/show_hide_search_test.dart`) cancels it. This is a test
   fix, not a source change.
3. Scope stayed inside the assessment: no changes to the already-guarded
   `code_field.dart` / `code_controller.dart` / `popup_controller.dart` sites.

## Verification

- `flutter test test/src/gutter/error_popup_dispose_test.dart test/src/search/search_enter_dispose_test.dart`
  → 4 tests, all green.
- B1 re-proved RED by `git stash push lib/src/gutter/error.dart` (same
  `setState() called after dispose()` exception), then restored.
- `flutter test` → **299 tests, all green** (295 pre-existing + 4 new).
- `dart analyze --fatal-infos` → 24 info-level issues, identical to the
  pre-existing master set (deprecations and `use_key_in_widget_constructors`);
  no new findings from the guards or the new tests.

Toolchain for verification: Flutter 3.47.5 (Dart 3.13.4), macOS.
