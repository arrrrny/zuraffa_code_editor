# Fix: `wrap: true` now soft-wraps long lines

Status: **applied** — branch `bug/wrap-true-does-not-wrap`, base master `0d57280`.
Source assessment: no separate `assessment.md`; the root cause was found in the
issue's own trace (`_numberScroll`-style dead flag) and confirmed by grep — the
parameter is stored and never read anywhere in `lib/`.
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/code_field/code_field.dart` | `_wrapInScrollView` branches on `widget.wrap` and skips the `IntrinsicWidth` + horizontal scroll view on the wrapping path; new `_editorTextWidth` captured from the editor's `LayoutBuilder` (with a post-frame rebuild once the field has a real width); `_wrappedRowHeights`, `_measureWrappedRows`, `_gutterRowExcess`, `_withoutLineBreak`, `_singleLineHeight`, `_codePosition` |
| `lib/src/gutter/gutter.dart` | `GutterWidget` takes an optional `rowHeights`; every cell goes through `_sized`, a no-op when the list is null |
| `test/src/code_field/wrap_true_test.dart` | **new** — 4 widget tests: wrapping reflows, unwrapped layout pinned, gutter/code extents agree and follow each other both ways, unwrapped extents unchanged |

## Deviations from the issue

- The issue only asks for wrapping. The gutter half is included because
  `wrap: true` with one-line-high gutter rows makes the numbers drift off
  their lines — a worse defect than the one being fixed. See the cycle log.
- Upstream never wired the flag either (`lib/src/code_field/code_field.dart`
  in `akvelon/flutter-code-editor@master` still stores it unused), so there
  is no upstream behaviour to match.

## Verification

- `flutter test test/src/code_field/wrap_true_test.dart` — 4/4 green
  (verified red on master: `Actual: <2903.0>`).
- `flutter test` — 496 tests, all passing.
- `dart analyze --fatal-infos` — No issues found.
- `dart format lib test` — clean.

## Coverage note

Only `wrap: true` builds take the new measurement path; `wrap: false` (every
existing test) keeps `rowHeights == null` and takes the same layout as before.
No change to `.github/workflows/dart.yaml`: the gate is a ratchet and this PR
adds no measured-coverage claim of its own.
