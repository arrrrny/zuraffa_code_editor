# Test List: batch-fold-blocks-116

Derived: 2026-10-12 · Engine: raw (see `.specify/memory/tdd-profile.md`)
Spec: ./spec.md · Plan: ./plan.md

## Acceptance behaviors

- [ ] A1 — `foldBlocks` folds every given block; the resulting `Code` is
      identical (foldedBlocks, hiddenRanges, visibleText) to folding them
      one-by-one with `foldAt`. (AC: "folds every given block")
      Traces to: `code_controller_fold_blocks_test.dart`
- [ ] A2 — One batch fold triggers exactly one `super.value` assignment and
      one listener notification for N blocks. (AC: "one value assignment and
      one listener notification")
- [ ] A3 — Already-folded and stale blocks (a block the current `Code` no
      longer holds) are skipped without throwing; when everything is skipped
      nothing is assigned and nobody is notified. (AC: "skipped without
      throwing")
- [ ] A4 — `foldImports()` and `foldOutsideSections()` keep their current
      visible behaviour with the upstream TODOs removed. (AC: "helpers keep
      behaviour")
      Traces to: `code_controller_folding_test.dart` +
      `code_controller_folding_editing_test.dart` (characterization guard,
      must stay green untouched)
- [ ] A5 — Selection recovery through a batch fold matches the single-fold
      path (`_selectionHiddenByFold` and the cut selection equal the `foldAt`
      loop's). (AC: "selection recovery matches")
- [ ] A6 — Coverage stays at the 100% gate. (AC: "coverage stays 100%")

## Characterization (regression) behaviors

- [ ] C1 — Every pre-existing folding test passes unchanged: single folds,
      the two helpers' current outputs, editing with folds, fold+unfold
      selection round-trips.

## Coverage obligations

- `lib/src/code/code.dart`: `foldedBlock` skip guard — both branches
  (already folded / stale → skip; foldable → fold); `foldedAt`'s new
  null-check delegation (block found by A1, null by the existing suite).
- `lib/src/code_field/code_controller.dart`: `foldBlocks` loop body and the
  `identical(newCode, _code)` early return (A3 all-skipped) plus the
  assignment path (A1/A2).
- Gate: 100% line coverage (`tool/coverage_gate.py --min 100`); count the
  insertions in both files before running it (EXEMPT_LINES pins by number).

## Cycle log

See `tdd/cycle-log.md`.
