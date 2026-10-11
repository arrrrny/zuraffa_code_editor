# Bug Assessment: Autocomplete needs a double tap on mobile and the popup is cut off

- **Slug**: autocomplete-double-tap-popup-84
- **Created**: 2026-10-11T06:08:33Z
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/84 (upstream `akvelon/flutter-code-editor#205`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> Editor on mobile autocomplete needs double click to select an item from the
> dropdown. Also the dropdown gets cutoff. Would be nice to have a custom
> autocomplete builder option. [includes a simulator screenshot showing the cutoff]

Filed on this fork as #84 (rank 1, `bug`/high) and again as #102 (rank 5,
`bug`/medium) — the same upstream #205 report under two labels.

## Symptom

Two defects on touch platforms: (1) the first tap on a suggestion only moves the
selection and hands focus back to the editor — the word is committed only by a
second tap; (2) the suggestion popup is clipped by the edge of the window rather
than being repositioned to fit.

## Reproduction

1. Run the editor on a phone-sized viewport (or the example app on a simulator).
2. Type a prefix with registered completions so the popup opens.
3. Tap a suggestion once: the row highlights and the editor takes focus, but no
   word is inserted.
4. Tap a second tap on the same row: the word is inserted. (Expected: one tap.)
5. With the caret near the right edge of a narrow editor, open the popup: it is
   positioned partly outside the window.

[NEEDS CLARIFICATION: the report's viewport width and caret column are not
stated, so the exact clipped edge cannot be pinned; the code below shows the
clip is reachable on any editor narrower than 400 px.]

## Suspected Code Paths

### Defect 1 — a tap does not commit

- `lib/src/wip/autocomplete/popup.dart:141-149` — the row's `InkWell` splits the
  two gestures: `onTap` sets `selectedIndex` and returns focus to the editor;
  `onDoubleTap` additionally calls `onCompletionSelected()`. Nothing else in the
  tree calls `onCompletionSelected` from a tap, so commit-on-tap does not happen.
- `lib/src/code_field/code_controller.dart:504-509` — `onEnterKeyAction`
  commits when the popup is showing, so Enter is the only single-keystroke
  commit path. `PopupController.onCompletionSelected` is bound to
  `insertSelectedWord` (`code_controller.dart:216`).
- `test/src/wip/autocomplete/popup_test.dart:81-85` — a test **pins the current
  behaviour**: `expect(completions, isEmpty, reason: 'a single tap only moves the
  selection, it does not commit')`. The file's doc comment (lines 6-9) describes
  it as intended. The fix must change this test, not route around it.
- `test/src/wip/autocomplete/popup_test.dart:6-14` — records the mechanism that
  makes the first tap feel dead: with both `onTap` and `onDoubleTap` on one
  `InkWell`, the gesture arena holds a single tap back until
  `kDoubleTapTimeout` expires.

### Defect 2 — the popup is placed against the wrong rectangle

- `lib/src/code_field/code_field.dart:362` and `:429` — `windowSize` is read from
  the **editor's own render box**, so `Popup.editingWindowSize` is the editor's
  size, not the viewport's.
- `lib/src/code_field/code_field.dart:956-967` and `_buildSuggestionOverlay` —
  the popup is inserted into the **full-screen `Overlay`** and positioned in
  **window** coordinates (both offsets add `_editorOffset`, which is
  `localToGlobal`).
- `lib/src/wip/autocomplete/popup.dart:130-135` — `_isHorizontallyOverflowed`
  therefore compares an editor-local offset against the editor's width, and
  `popup.dart:65-70` computes `leftOffsetLimit` as
  `editingWindowSize.width - maxWidth + editorOffset.dx - 100`, with the `-100`
  unexplained (`TODO(nausharipov): find where 100 comes from`, line 66). For any
  editor narrower than 400 px the limit is negative, so the popup is placed
  partly outside the window on the left.
- `lib/src/wip/autocomplete/popup.dart:118-128` — `_isVerticalFlipRequired`
  uses `Sizes.autocompletePopupMaxHeight` (100) rather than the height the
  suggestions actually need, and refuses to flip at all when
  `isPopupShorterThanWindow` is false, i.e. when the editor is shorter than
  100 px. `lib/src/code_field/code_field.dart:874-875` mirrors the same
  assumption in `_flippedPopupOffset`.

## Root Cause Hypothesis

Both are placement/contract mistakes in a module marked `wip`, and they compound:
the gesture split in `popup.dart` makes the commit path a double tap, while the
placement math treats the editor's own box as the viewport and adds an
unexplained 100 px fudge when clamping horizontally — so on a phone, where the
editor fills the screen, the clamp pushes the popup off the left edge.

Confidence: **high** for defect 1 (the call sites are exhaustive and the current
behaviour is pinned by a test). **Medium** for defect 2 — the arithmetic is
demonstrably wrong for a narrow editor and the `-100` is unexplained, but the
report's screenshot is not available, so which edge clips on the reporter's
device is inferred from the math rather than observed.

## Proposed Remediation

**Preferred**: two changes, both inside `lib/src/wip/autocomplete/` and
`lib/src/code_field/` — neither touches the package's public surface, because
`lib/zuraffa_code_editor.dart` does not export `src/wip/`.

1. Commit on a single tap. Move `onCompletionSelected()` into `onTap` and drop
   `onDoubleTap`. Dropping it is not cosmetic: with both handlers on one
   `InkWell` the arena holds a single tap until `kDoubleTapTimeout`, so keeping
   it would make tap-to-select take ~300 ms. `insertSelectedWord` already hides
   the popup, so the second half of a double tap cannot re-commit after the
   first tap has committed and removed the row. This matches Flutter's own
   autocomplete contract and Enter's behaviour in `onEnterKeyAction`.
2. Place the popup against the viewport. Inside `Popup.build`, take the window
   size from `MediaQuery.of(context)` rather than from
   `Popup.editingWindowSize`, and clamp instead of guessing: `left ∈ [0,
   windowWidth - popupWidth]`, `top ∈ [0, windowHeight - popupHeight]`. Decide
   the vertical flip on the height the suggestions actually need
   (`min(itemCount * itemHeight, maxHeight)`) rather than on the constant. The
   `-100` fudge and the `TODO` above it disappear with the clamp.

**Alternatives**:
- Keep `onDoubleTap` and add a separate tap-up commit on a `GestureDetector`
  wrapping the `InkWell`. Rejected: two recognizers on one row, and it leaves the
  arena hold in place.
- Add a `customAutocompleteBuilder` as the report suggests. Rejected as the
  primary fix: it is a feature request (fork #87 already tracks suggestion-popup
  customization) and would leave both defects in place for every host that does
  not supply a builder.

**Files likely to change**:

- `lib/src/wip/autocomplete/popup.dart`
- `lib/src/code_field/code_field.dart` (offset computation)
- `test/src/wip/autocomplete/popup_test.dart` (the pinned behaviour)
- `test/src/code_field/autocomplete_popup_background_test.dart` (pumps the
  popup through the field — its expectations may need to follow the new
  placement)

**Tests to add or update**:

- Single tap on a row commits: `onCompletionSelected` called exactly once, the
  word inserted, the popup hidden. Drives the touch path (`wt.tap`), not mouse.
- Single tap does not wait for the double-tap timeout: the commit is observable
  after a short pump, without a `kDoubleTapTimeout` wait.
- The popup stays inside the window when the caret is near the right edge of a
  narrow editor: assert the `Positioned`'s `left` is `>= 0` and
  `left + width <= windowWidth`.
- The popup stays inside the window when the caret is near the bottom edge: the
  flip is chosen on the needed height, not on the constant.
- Keyboard navigation (arrow up/down, Enter) unchanged.

## Risks & Considerations

- **The existing test asserts the bug.** `popup_test.dart:81-85` must be updated;
  leaving it green would mean the fix is not applied. Record the change in the
  commit and the CHANGELOG.
- **The commit becomes single-tap on desktop too.** The report asks that desktop
  behaviour be unchanged; a uniform tap-to-commit is the conventional contract
  and the only way a single tap can select on touch, but it does mean a desktop
  click now commits where it previously only moved the highlight. Keyboard and
  hover behaviour are untouched. Flagging explicitly so the reviewer can weigh it.
- **`windowSize` is the editor box, not the viewport.** Correcting the flip
  changes behaviour on desktop layouts where the editor occupies part of the
  window — the popup will stop flipping when there is window space below it.
  That is the intended fix, but it is a visible change beyond the reported
  mobile case.
- `lib/src/wip/` is excluded from the coverage gate's `EXEMPT_FILES`, so the new
  placement code must be covered by tests, not exempted.
- The report also asks for a custom autocomplete builder. Out of scope here;
  tracked separately.

## Open Questions

- [NEEDS CLARIFICATION: the reporter's viewport width and caret column, which
  would pin the clipped edge exactly. The arithmetic pins the class of failure
  (editors narrower than 400 px) without it.]
- [NEEDS CLARIFICATION: whether single-tap-commit should also apply on desktop,
  or only when the device has touch. The uniform behaviour is proposed; the
  alternative needs a platform check that Flutter's own autocomplete does not
  have.]
