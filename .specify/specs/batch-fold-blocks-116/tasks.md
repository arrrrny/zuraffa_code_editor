# Tasks: batch fold blocks

**Spec:** ./spec.md · **Plan:** ./plan.md · **Test list:** ./tdd/test-list.md

## Phase 1 — the tests (red)

- [ ] T1 `test/src/code_field/code_controller_fold_blocks_test.dart`: new file
      with the batch-API tests — identical result to the `foldAt` loop (A1),
      one `super.value` assignment and one listener notification for N blocks
      (A2), already-folded and stale blocks skipped without throwing (A3),
      selection recovery matches the single-fold path (A5), zero-assignment
      when everything is skipped. Red: `foldBlocks` does not exist.

## Phase 2 — the block-native fold (behaviour)

- [ ] T2 `lib/src/code/code.dart`: `foldedBlock(FoldableBlock)` — skip when
      already folded or not in `foldableBlocks` (stale), otherwise the same
      hidden-range + `_copyWithFolding` body `foldedAt` uses.
- [ ] T3 `lib/src/code/code.dart`: `foldedAt` delegates to `foldedBlock`
      after its existing line resolution (guard collapsed to a null check),
      so the two paths cannot drift.

## Phase 3 — the batch controller API (behaviour)

- [ ] T4 `lib/src/code_field/code_controller.dart`: `foldBlocks(Iterable<
      FoldableBlock>)` — fold into the accumulating `Code`, assign
      `super.value` + update `_code` once, skip the assignment when nothing
      folded (`identical`).

## Phase 4 — delegate the helpers (behaviour, characterization-guarded)

- [ ] T5 `lib/src/code_field/code_controller.dart`: `foldImports()` delegates
      to `foldBlocks(... where isImports)`; the upstream TODO is removed.
- [ ] T6 `lib/src/code_field/code_controller.dart`: `foldOutsideSections()`
      keeps its line-set computation and resolves each surviving line to its
      first matching `foldableBlocks` entry; delegates to `foldBlocks`; the
      upstream TODO is removed.

## Phase 5 — records

- [ ] T7 `tool/coverage_gate.py`: renumber any pinned lines the insertions
      shifted (count them before running the gate).
- [ ] T8 `CHANGELOG.md`: entry naming fork issue #116 and upstream
      `akvelon/flutter-code-editor#106`.
- [ ] T9 Coverage gate: `flutter test --coverage --concurrency=2` +
      `python3 tool/coverage_gate.py --min 100`, cleaning the helper test and
      `coverage/` afterwards.

## Dependencies

T1 is red against everything. T2+T3 take A1/A3/A5 green at the `Code` level;
T4 takes A2 green. T5/T6 are pure delegation once T4 exists — the existing
`code_controller_folding_test.dart` and `code_controller_folding_editing_test.dart`
suites are the characterization guard (A4) and must stay green untouched.
T7 must count the T2/T4/T5/T6 insertions. T8/T9 last.

## Test inventory (for T1)

1. **Identical to the loop** — fold N blocks via `foldBlocks`, and via a
   `foldAt` loop on a second controller; `foldedBlocks`, `hiddenRanges` and
   `visibleText` match.
2. **One assignment, one notification** — a listener on the controller counts
   exactly one notification for a 3-block batch; `value` changed once.
3. **Skips** — an already-folded block and a block from another `Code`
   (stale) are skipped without throwing.
4. **All-skipped** — every given block already folded or stale: no value
   assigned, no notification.
5. **Selection recovery** — a selection inside the folded ranges is cut and
   recoverable exactly as the single-fold path leaves it (`_selectionHiddenByFold`
   state compared).

## Parallelism

T2/T3 same file (sequential); T4 depends on T2; T5/T6 depend on T4 and are
independent of each other; T7 after all insertions; T8/T9 last.
