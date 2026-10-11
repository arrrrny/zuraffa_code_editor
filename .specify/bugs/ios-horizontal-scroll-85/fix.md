# Fix record: ios-horizontal-scroll-85

- **Slug**: ios-horizontal-scroll-85
- **Branch**: `bug/ios-horizontal-scroll-85` (from master `a02539a`)
- **Date**: 2026-10-11
- **Issue**: https://github.com/arrrrny/zuraffa_code_editor/issues/85
  (upstream akvelon/flutter-code-editor#280)

## Summary

**No behaviour change. No file under `lib/` was modified.**

Issue #85 reports horizontal scrolling as broken on iOS and working on Android.
Measured, that is the wrong way round, and the difference is not this package's to
fix: on master the code area scrolls horizontally on drag under an iOS platform
override and does not under an android one, because Flutter's `TextField` registers
a `TapAndHorizontalDragGestureRecognizer` whose `eagerVictoryOnDrag` is
`defaultTargetPlatform != TargetPlatform.iOS`
(`packages/flutter/lib/src/widgets/text_selection.dart:3731`). That recognizer is
deeper in the hit-test tree than the code area's `SingleChildScrollView`, enters
the gesture arena first, and on non-Apple platforms resolves the arena in its own
favour, turning the drag into a text selection.

The caret reveal — the platform-independent half I first suspected was missing —
already works on every platform (`End`, `Home`, `→`, tap-to-position and IME entry
all move `_horizontalCodeScroll`), because `TextField`'s
`RenderEditable.showOnScreen` drives it. My first measurement of it was wrong: the
field must be focused, since `_scheduleShowCaret` is gated on focus.

## What changed

| File | Change |
|------|--------|
| `test/src/code_field/horizontal_scroll_behaviour_test.dart` | **new** — 6 pins over the measured behaviour (see below) |
| `.specify/bugs/ios-horizontal-scroll-85/{issue,assessment,spec,test,fix}.md` | new assessment chain |
| `.specify/bugs/ios-horizontal-scroll-85/tdd/{test-list,cycle-log}.md` | new TDD record |

Nothing in `lib/`, `example/`, `tool/` or `pubspec.yaml`.

## The pins

| Pin | What it protects |
|-----|------------------|
| drag under an iOS platform override scrolls `_horizontalCodeScroll` | acceptance criterion 1 and 4 of the issue — the code area reaches content past the right edge on iOS |
| the same drag under an android platform override does not scroll | the Flutter platform split is visible in the suite instead of implied, so a Flutter upgrade that flips `eagerVictoryOnDrag` turns this red on purpose |
| `End`/`Home`/`→` reveal the caret horizontally | acceptance criterion 2 — the reveal is platform-independent |
| typing a long line ends with the caret revealed | the IME path, via `RenderEditable.showOnScreen` |
| content that fits the viewport is not scrolled | no spurious scroll on short documents |
| `wrap: true` has no horizontal scroll view at all | the unwrapped/wrapped split in `_wrapInScrollView` |

## Verification

- Full suite: **737 passed** on the unfixed baseline (the six new pins green on an
  unmodified `lib/`).
- `dart analyze` on the changed files: no issues.
- `dart format`: clean.
- Coverage gate: unchanged at 100% (3360/3360) — the new file is test code, so it
  adds no production lines.
- Measurements reproduced with throwaway probes (`test/tmp_probe85*_test.dart`,
  all deleted before the commit); the numbers are transcribed in
  `.specify/bugs/ios-horizontal-scroll-85/tdd/cycle-log.md`.

## Deviations from the assessment

- The assessment's first draft listed a second, platform-independent defect
  ("nothing reveals the caret horizontally"). The focused re-measurement
  disproved it; the assessment, the spec and the tests were rewritten. The wrong
  turn is recorded in `cycle-log.md` rather than dropped.
- The proposed remediation became "ship pins, no behaviour change" after the
  focused re-measurement made it clear there was nothing to fix in this package.

## Follow-up (out of scope, documented)

An interactive horizontal `Scrollbar` on the code area is the correct way to reach
the right edge on the platforms where dragging the code text selects instead of
scrolling: the thumb drag uses its own `HorizontalDragGestureRecognizer`, deeper
than the `TextField`'s, so it wins the same arena without touching selection.
Material's `ScrollBehavior.getScrollbars` suppresses scrollbars on Android/iOS, so
shipping it needs a `showScrollbar: true` (a mobile UI change) or a platform
decision — its own issue.
