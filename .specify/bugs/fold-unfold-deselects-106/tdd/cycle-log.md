# Cycle log: fold-unfold-deselects-106

Project is not zuraffa-wired (`.zfa.json` absent) — LLM-guided loop per the
`/speckit-tdd-run` fallback. Baseline: master `1b8634f`, branch
`bug/fold-unfold-deselects-106`.

## Red — the reproduction was the hard part

The issue body is a screen recording, and its stated location
(`lib/src/folding/fold_toggle.dart`) does not exist in this repo. Instrumented
probes on unmodified master, in this order (all deleted afterwards):

1. Controller-level `foldAt` + `unfoldAt` with a selection before/after — the
   selection survived. Not the bug.
2. A real gutter `FoldToggle` tap through a pumped `CodeField` with a
   programmatic selection — also survived. Not the bug.
3. `focusNode.unfocus()` in isolation — survived. Not the bug.
4. A selection overlapping the fold — the doc's own assertion
   `controller.code.foldedBlocks` stayed empty, so `foldAt(2)` on that document
   folded nothing and the probe was vacuous.
5. A real **mouse-drag** selection inside the code area, then the gutter
   toggle of a block the selection does not touch:

```
mouse sel  : TextSelection(baseOffset: 58, extentOffset: 97, isDirectional: false)
after tap  : TextSelection(baseOffset: 45, extentOffset: 84, isDirectional: false)
after unfold: TextSelection(baseOffset: 58, extentOffset: 97, isDirectional: false)
```

This settles the report's own claim: a selection *untouched* by the fold is
correctly tracked and restored. It also rules out the obvious suspects —
focus loss, the gutter's gesture detector, and the `FoldToggle` callback.

6. A selection **covered** by the folded block, on a document whose
   `foldAt(1)` hides full-text `[42, 55]`:

```
blocks: [FoldableBlock(0, 8, ...), FoldableBlock(1, 3, ...), FoldableBlock(5, 7, ...)]
ranges after fold: [HiddenRange(42, 55, 1, 3, false)]
```

   `[43, 58]` → `[42, 45]`, and the unfold leaves it at `[42, 45]`.
   A caret at `47` → `42`, and a straddling `[0, 44]` → `[0, 42]`, both equally
   stuck. This is the defect.

## Green

Fix applied (see `fix.md`); all 7 tests green, full suite 776/776.

## Verify

- `dart analyze` — no issues.
- `dart format --output=none --set-exit-if-changed .` — clean.
- `flutter test` — 776/776, including the pre-existing
  `no_language_keystroke_test.dart` ratio pin (flaky under full-suite load on
  some runs; green here and green in isolation).
- Coverage gate — 100.00%.
- Fault injection: reverting only the assignment of
  `_selectionHiddenByFold` reddens 4 of the 7 tests; the 3 regression pins
  stay green.
