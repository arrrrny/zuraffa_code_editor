# #20 — Tab renders as a tofu box in CanvasKit

- **Status:** the rendering fault is gone, but verification found one live path
  that still put a raw `\t` into the code; fixed here with regression tests
- **Label:** `bug`
- **Source:** upstream `akvelon/flutter-code-editor#67`

## Reported symptom

Tabs render as an unknown-symbol box in a web (CanvasKit) build of the editor.

## Where the bug actually lives

Two separate things carry the "tofu" name:

1. **CanvasKit had no glyph for `\t`** — flutter/flutter#79153, fixed on the
   Flutter master channel in September 2022. This fork's floor is
   Flutter >= 3.10, well past it, and the upstream maintainers said they were
   only keeping the issue open until that reached stable.
2. **A tab reaching the text at all.** Upstream's mitigation was to never let
   one: replaced with spaces on loading (PR #66) and on Tab keypress
   (`TabModifier`). This fork has both, so on paper no tab can render.

## What this fork already had

- `fullText` setter — `lib/src/code_field/code_controller.dart:447`, routed
  through `_replaceTabsWithSpacesIfNeeded` (`:861`), which converts only when
  a `TabModifier` is among the `modifiers`.
- the `value` setter's normal editing path —
  `lib/src/code_field/code_controller.dart:528-530`, `newValue.tabsToSpaces(...)`.
- `defaultCodeModifiers` contains `TabModifier()`, so both are on by default.

Pin‑ned by `test/src/code_field/code_controller_tab_test.dart` (load, custom
`tabSpaces`, several insertions, opt-out when `TabModifier` is absent).

## The gap this verification found

The composition branch of `value=` (`code_controller.dart:492-501`) exists to
preserve platform-provided editing state — it deliberately applies no editor
transforms. The tab conversion was part of the transform block *below* it, so a
tab that arrived inside an IME composition update (a paste into a composing
region is the realistic shape) went straight into `_code`:

```
Expected: 'ab  '
  Actual: 'ab\t'
```

The tab then renders as tofu in exactly the situation the issue reports.

## The change

- `lib/src/code_field/code_controller.dart` — the composition branch converts
  the value first when tab replacement is enabled, so the platform value and
  the code built from it cannot disagree about tabs.
- `lib/src/code_field/text_editing_value.dart` — two corrections to
  `tabsToSpaces`, both needed by the line above:
  - it handed `composing` through **unchanged**, so converting a value whose
    composing region contains or precedes a tab left the composing range
    pointing at stale offsets;
  - it assumes a selection inside the text, and threw
    `RangeError (end): Invalid value: Not in inclusive range 0..3: 5` on the
    transient platform state an existing IME test documents (the composition
    shrinks while the platform selection still points past the new end). The
    selection is now clamped to the text it points into.

## Tests

`test/src/code_field/tab_tofu_canvaskit_test.dart` — five tests: load, a tab
arriving in a platform value update, a tab arriving while composing, a tab
committed by composition, and the no-`TabModifier` opt-out.

`test/src/code_field/tabs_to_spaces_test.dart` — three tests: a selection past
the end of the text, a composing range past the end, and a composing range that
spans tabs (the remap).

## Fault-detecting power

Measured by reverting each source change on its own:

- reverting the controller change fails both composition tests:
  `Expected: 'ab  ' / Actual: 'ab\t'` and `Expected: 'ab  x' / Actual: 'ab\tx'`;
- reverting `text_editing_value.dart` fails
  `with a selection past the end of the text` (the `RangeError` above) and
  `with a composing range that spans tabs`
  (`Expected: TextRange(start: 15, end: 42) / Actual: TextRange(start: 14, end: 40)`).

## Conclusion

The CanvasKit half of #20 needs no code — it was a Flutter rendering bug fixed
four years before this fork's floor. The half that did need code, a tab
surviving into the text through the composition path, is fixed and pinned.

## Gate note

`EXEMPT_LINES` in `tool/coverage_gate.py` keys the dead
`throw AssertionError('')` in `select()` by line number; the new helper above
it moved that line 188 → 229. Only the key moved — the proof comment is
unchanged and the exempted-line count stays 13. Coverage is 100.00 %
(3108/3108).
