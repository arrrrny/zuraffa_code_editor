# Cycle Log: batch-fold-blocks-116

Engine: raw (`.specify/memory/tdd-profile.md`). One behavior at a time:
red proven → smallest change → green → tick.

## Baseline — 2026-10-12

- Suite: `flutter test --concurrency=2` on `spec/batch-fold-blocks-116` @
  `90366bf` (master `25e4c1a` + spec commit).
- Test list written: 6 behaviors (A1–A6 acceptance, C1 characterization).
- Behaviors DONE: 0/6.

## Loop — 2026-10-12

- **Red (T1)**: new `test/src/code_field/code_controller_fold_blocks_test.dart`
  with 5 tests (A1, A2, A3, A5, all-skipped). Compile-red: `foldBlocks`
  isn't defined — the honest red for a new API.
- **Green (T2–T4)**: `Code.foldedBlock(FoldableBlock)` added next to
  `foldedAt`; `foldedAt` delegates to it after its existing line
  resolution (guard collapsed to a null check). `CodeController.foldBlocks`
  folds into the accumulating `Code`, assigns once, skips the assignment
  when nothing folded (`identical`).
- **Expectation fix (mine, not the code's)**: the A2 twin-loop comparison
  expected one loop notification per block. Actually 1, not 4 — folding a
  block nested inside an already-folded one leaves the visible value
  equal, so `super.value` does not notify. The "N intermediate states"
  pathology is about independent folds. Test now folds pairwise-disjoint
  leaf blocks and asserts disjointness with a reason, so a fixture change
  fails loudly.
- **Green (T5/T6)**: `foldImports` delegates to
  `foldBlocks(... where isImports)`; `foldOutsideSections` keeps its
  line-set computation, resolves each surviving line to its first matching
  `foldableBlocks` entry, delegates. Both upstream TODOs removed.
- Characterization guard: `code_controller_folding_test.dart` (incl. the
  two helpers' groups) + `code_controller_folding_editing_test.dart` +
  `fold_unfold_keeps_selection_test.dart` + `test/src/code/` — 124 green,
  untouched. Full suite 824 green (819 + 5 net).
- `dart analyze --fatal-infos` clean, `dart format` clean.
- Behaviors DONE: 6/6 (A1–A6, C1).
