## Summary

Fixes #84 (upstream `akvelon/flutter-code-editor#205`): on mobile the
autocomplete dropdown needed a double tap and was cut off.

**A single tap commits.** `Popup`'s row carried the commit on `onDoubleTap`, so
the gesture arena held the first tap back until the double tap timeout expired
and the first tap only moved the highlight. `onTap` now commits the word on its
row exactly as Enter does — selection, focus back to the editor, and
`onCompletionSelected()` — and `onDoubleTap` is gone, so there is no arena left
to hold the tap. The tap is driven through `wt.tap` (the touch path), and the
commit is observable after a 100 ms pump, far under `kDoubleTapTimeout`.

**The popup fits the window.** The popup is inserted into the full-screen
overlay at *window* coordinates, but measured every bound against the
*editor's* render box:

- the horizontal clamp subtracted an unexplained 100 px
  (`left = editingWindowSize.width - 300 + editorOffset.dx - 100`, with a
  `TODO(nausharipov)` over the constant), which is negative for any editor
  narrower than 400 px — a phone-sized editor pushed the popup off the left
  edge;
- the vertical flip was refused outright when the editor was shorter than the
  popup's maximum height, and otherwise forced by the constant 100 rather than
  the height the suggestions actually need.

The popup is now clamped into the window it is given — `left ∈ [0, window -
maxWidth]`, the unflipped `top ∈ [0, window - neededHeight]` and the flipped
`top ∈ [0, window - maxHeight]`, since the flipped box is bottom-aligned — and
the flip compares the needed height (one measured row per suggestion, capped at
the popup's maximum height) against the window. `CodeField` fills the popup's
`windowSize` from `MediaQuery` instead of its own render box, which was the
root cause: the popup's "window" was the editor.

The `-100` and its TODO, and the now-unused `editorOffset` parameter, are
removed. `_isHorizontallyOverflowed` and `_isVerticalFlipRequired` go with them
— both measured the editor box.

## Changes

| File | Change |
|------|--------|
| `lib/src/wip/autocomplete/popup.dart` | `onTap` commits; `onDoubleTap` dropped; window-clamped placement and needed-height flip; dead math and parameter removed |
| `lib/src/code_field/code_field.dart` | the popup's `windowSize` comes from `MediaQuery`, not the field's render box |
| `test/src/wip/autocomplete/popup_test.dart` | the tap test now asserts the commit (it used to assert it did *not* happen); the double-tap test became "the tapped row is the one committed" |
| `test/src/wip/autocomplete/popup_placement_test.dart` | new — 7 placement cases with explicit geometry |
| `test/src/code_field/tap_accepts_suggestion_test.dart` | new — 6 cases through the real field: tap commits and hides, no double-tap wait, arrows + Enter unchanged, a 300 px window, a short editor pinned to the bottom of the window, room below |
| `tool/coverage_gate.py` | the `popup.dart` line exemption moved 76 → 80 with the rewrite |
| `CHANGELOG.md` | Unreleased → Changed |

## Behaviour notes for review

- **Single-tap commit is uniform across platforms.** The issue asks for desktop
  behaviour to be unchanged; the assessment flagged this as a risk and the
  decision was to commit on tap everywhere. A platform check would need a
  `PointerDeviceKind` test that Flutter's own autocomplete does not have, and
  a click that only moves the highlight without committing has no use on
  either platform. On desktop a habitual double click still ends with the word
  committed: the first click does it, the second lands on the editor. This is
  the one visible change for a desktop-only user.
- **The reporter's custom autocomplete builder** request is a feature, not a
  defect, and is left as a follow-up.

## Local verification

- `flutter test` → **747/747 green** on master `89ff2c6`.
- Coverage gate → **100.00% (3358/3358 lines)**; every new line in
  `popup.dart` is covered by the new tests, including the empty-list and
  capped-height branches.
- `dart analyze` on the changed files → only the three pre-existing
  `withOpacity` deprecation infos from master's row code. `dart format` clean.
- The red state before the fix is recorded in
  `.specify/bugs/autocomplete-double-tap-popup-84/tdd/cycle-log.md` with the
  exact values master produced (`left = -10`, `left = -100`, unflipped
  `top = 572`, a spurious flip to `430`, and text unchanged after a tap).

Closes #84

Assessment: `.specify/bugs/autocomplete-double-tap-popup-84/assessment.md`
