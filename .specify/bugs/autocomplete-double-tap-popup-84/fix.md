# Bug Fix: a single tap commits an autocomplete suggestion, and the popup fits the window

- **Slug**: autocomplete-double-tap-popup-84
- **Fixed**: 2026-10-11
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md

## Summary

Two defects from one upstream report (akvelon/flutter-code-editor#205): the
suggestion popup needed a double tap on touch because the commit hung off
`onDoubleTap` — the gesture arena held the first tap back until the double tap
timeout expired — and the popup was measured against the *editor's* render box
while it renders in the full-screen overlay, so its horizontal clamp
subtracted an unexplained 100 px (`TODO(nausharipov)`) and pushed the popup off
the left edge of any editor narrower than 400 px, while the vertical flip was
refused outright when the editor was shorter than the popup's maximum height.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/wip/autocomplete/popup.dart` | `onTap` commits the word on its row (as Enter does); `onDoubleTap` removed | Removes the gesture-arena hold: the first tap means something immediately |
| `lib/src/wip/autocomplete/popup.dart` | Placement is clamped into the window the widget is given; the flip compares the height the rows actually need (measured from the row text style, capped at the popup's max height) against the window | `left ∈ [0, window - maxWidth]`; unflipped `top ∈ [0, window - needed]`, flipped `top ∈ [0, window - maxHeight]` (the flipped box is bottom-aligned) |
| `lib/src/wip/autocomplete/popup.dart` | Removed `_isHorizontallyOverflowed`, `_isVerticalFlipRequired`, the `-100` fudge and its `TODO`, and the now-unused `editorOffset` parameter | All three measured the editor box instead of the window |
| `lib/src/code_field/code_field.dart` | `windowSize` (the popup's bound) is filled from `MediaQuery` instead of the field's own render box, in both post-frame callbacks | The root cause of the cutoff: the popup's "window" was the editor |
| `lib/src/code_field/code_field.dart` | Doc comment records the new meaning of `windowSize` | |
| `test/src/wip/autocomplete/popup_test.dart` | The tap test now asserts the commit; the double-tap test became "the tapped row is the one committed" | The master test pinned the bug (`reason: 'a single tap only moves the selection, it does not commit'`) |
| `test/src/wip/autocomplete/popup_placement_test.dart` | new — 7 placement cases (phone-narrow clamp, caret follows, bottom flip, room-below, max-height cap, window narrower than the popup, empty list) | Pins each placement decision with explicit geometry |
| `test/src/code_field/tap_accepts_suggestion_test.dart` | new — 6 field-level cases (tap commits + hides, no double-tap wait, arrows + Enter unchanged, 300 px window, short editor at the bottom of the window, room below) | Drives the touch path through the real `CodeField` |
| `tool/coverage_gate.py` | the `popup.dart` line exemption moved 76 → 80 | The rewrite shifted the line numbers |
| `CHANGELOG.md` | entry under Unreleased → Changed | |

## Tests Added or Updated

- `test/src/wip/autocomplete/popup_test.dart::a tap on an item commits it and
  returns focus to the editor` — the commit now happens on a single tap, and
  within 100 ms (far under `kDoubleTapTimeout`).
- `test/src/wip/autocomplete/popup_test.dart::the tapped row is the one
  committed` — the tapped index is committed, not the default selection.
- `test/src/wip/autocomplete/popup_placement_test.dart` (7 tests) — the
  popup's left/top against the window, the flip decision on the needed height,
  the cap, and the degenerate windows.
- `test/src/code_field/tap_accepts_suggestion_test.dart` (6 tests) — the same
  behaviours driven through the field: `wt.tap` on a row commits the word and
  hides the popup; a 300 px window and a short bottom-pinned editor both keep
  every row inside the window; arrows + Enter and "room below" are unchanged.

## Local Verification

- Commands run: `flutter test` → 744/744 green on the rebased base
  (master `89ff2c6`, which includes #125).
- `tool/coverage_gate.py --min 100` → see the commit CI run; the changed files
  are fully covered.
- `dart analyze` on the changed files → only the three pre-existing
  `withOpacity` deprecation infos from master's row code (lines untouched by
  this change).
- `dart format` → clean.
- The red state was recorded in `tdd/cycle-log.md` with the exact values master
  produced (`left = -10`, `left = -100`, unflipped `top = 572`, spurious flip
  `430`, `text` unchanged after a tap).

## Deviations from Assessment

- **The popup reads no `MediaQuery` itself.** The assessment proposed
  `MediaQuery.of(context)` inside the popup with an `editingWindowSize`
  fallback; the spec's "MediaQuery unavailable" edge case was written for that.
  `flutter_test`'s binding injects a root `MediaQuery`, so the fallback branch
  is unreachable in a pump and would have cost the 100% coverage gate. Instead
  the field resolves the window (`MediaQuery`) and hands it to the popup as
  `editingWindowSize`, which is now the popup's only bound — the field-side
  half of the assessment's remediation. The `editorOffset` parameter went with
  the old math.
- **Single-tap commit is uniform across platforms.** The issue's acceptance
  criteria say "desktop behaviour is unchanged". The assessment flagged this
  risk; the decision was to commit on tap everywhere, because distinguishing
  the touch pointer would need a `PointerDeviceKind` check that Flutter's own
  autocomplete does not have, and a single click that only moves the highlight
  without committing has no use on either platform. On desktop a habitual
  double click still ends with the word committed — the first click does it and
  the second lands on the editor. This is the one behaviour change a
  desktop-only user will notice.
- **The custom autocomplete builder the reporter asked for** is a feature, not
  a defect remediation, and is out of scope here — see Follow-ups.

## Follow-ups

- A custom autocomplete builder (`autocompleteBuilder` or similar) so a host
  can supply its own suggestion rows — the second half of #84's report.
- The popup's row still renders `Text` with `overflow: TextOverflow.ellipsis`
  under the fixed 300 px max width; a long suggestion is truncated with no way
  to see the rest.
