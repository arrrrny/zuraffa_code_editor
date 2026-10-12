# Spec: batch-fold-blocks

Fork issue: #116 · Upstream: akvelon/flutter-code-editor#106
Label: `spec` · Severity: `low` · Backlog rank: 19

## What was asked

"Batch folding API instead of repeated `fold()` calls." (Where it lives:
`CodeController`.)

## What exists today

`CodeController.foldAt(int line)` folds one block. Folding many means calling
it in a loop, and the package itself does exactly that in two places —
`foldImports()` and `foldOutsideSections()` — each carrying the upstream TODO:
"An optimized method to fold multiple blocks,
https://github.com/akvelon/flutter-code-editor/issues/106".

Each `foldAt` call rebuilds the `Code` (a fresh folded-block set and hidden
ranges), assigns `super.value` (a fresh `TextEditingValue` over the visible
text) and notifies listeners. Folding N blocks therefore pays for N
intermediate states the user never sees: a 300-import file triggers 300 value
assignments, each of which re-runs selection recovery and every listener,
before settling on the state the last call alone would have produced.

## What this spec adds

1. **`CodeController.foldBlocks(Iterable<FoldableBlock>)`** — folds the given
   blocks in one pass: one new `Code`, one `super.value` assignment, one
   listener notification, regardless of how many blocks were folded. Blocks
   that are not foldable (already folded, or no longer in the code) are
   skipped rather than throwing.
2. **The two batch helpers delegate to it** — `foldImports()` and
   `foldOutsideSections()` keep their exact behaviour and signatures; the
   upstream TODOs are removed.

## Decisions

- **Take the blocks, not the lines.** Every caller inside the package holds
  `FoldableBlock`s already; `foldLines.forEach(foldAt)` in
  `foldOutsideSections` is the line shape only because lines were the only
  API. A `FoldableBlock` argument cannot name a line that is not a fold start,
  which is a failure mode `foldAt(int)` accepts silently.
- **One value assignment is the point.** The spec's success criterion is
  observable: a listener attached to the controller sees one update for a
  batch fold, where today it sees N.
- **Selection semantics are inherited, not re-derived.** The batch folds
  through the same hidden-range machinery `foldAt` uses, so the
  selection-recovery behaviour (`_getValueWithCode`) is unchanged — pin it
  with the same class of assertion the single-fold tests use.
- **No `foldAll()`.** "Fold everything" is `foldBlocks(_code.foldableBlocks)`
  on the caller's side; adding named conveniences is scope the issue did not
  ask for.

## Out of scope

- Unfold-in-batch (`unfoldAt` keeps its single-block shape; nothing in the
  package loops it).
- Changing `foldAt`/`unfoldAt` behaviour or `Code.foldedAt`.
- A named-section-aware batch API.

## Acceptance criteria

- [ ] `foldBlocks` folds every given block; the resulting `Code` is identical
      to what folding them one-by-one with `foldAt` produces.
- [ ] One batch fold triggers exactly one `super.value` assignment and one
      listener notification for N blocks.
- [ ] Already-folded and stale blocks (no longer at that line) are skipped
      without throwing.
- [ ] `foldImports()` and `foldOutsideSections()` keep their current visible
      behaviour, with the upstream TODOs removed.
- [ ] Selection recovery through a batch fold matches the single-fold path.
- [ ] Coverage stays at the 100% gate.

## Gates

`flutter test` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
