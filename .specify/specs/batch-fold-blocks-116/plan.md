# Plan: batch fold blocks

**Spec:** ./spec.md
**Issue:** [arrrrny/zuraffa_code_editor#116](https://github.com/arrrrny/zuraffa_code_editor/issues/116) (upstream `akvelon/flutter-code-editor#106`)
**Label:** `spec`

## Design

The per-fold machinery already exists and is correct; the batch is about doing
it once instead of N times. `Code.foldedAt(int line)` resolves a line to a
block, skips gracefully when there is nothing to fold, and rebuilds the `Code`
through `_copyWithFolding`. `CodeController.foldAt` wraps it with one
`super.value` assignment and one `_code` update. This plan adds the
block-native halves and composes them.

### 1. `lib/src/code/code.dart` — `foldedBlock(FoldableBlock)`

The block-native sibling of `foldedAt`, sharing its body:

```dart
Code foldedBlock(FoldableBlock block) {
  if (foldedBlocks.contains(block) || !foldableBlocks.contains(block)) {
    // ignore: avoid_returning_this
    return this;
  }

  final hiddenRange = foldableBlockToHiddenRange(block);
  final newHiddenRangesBuilder =
      _hiddenRangesBuilder.copyWithRange(block, hiddenRange);

  return _copyWithFolding(
    foldedBlocks: {...foldedBlocks, block},
    hiddenRangesBuilder: newHiddenRangesBuilder,
  );
}
```

`foldedAt` delegates to it after its existing line resolution, so the two
cannot drift:

```dart
Code foldedAt(int line) {
  final block = _getFoldableBlockByStartLine(line);
  return block == null ? this : foldedBlock(block);
}
```

The `!foldableBlocks.contains(block)` guard is what makes a stale block — one
the current `Code` no longer holds — a skip instead of a bogus fold: the batch
API takes block objects, and a caller may hold blocks from an older parse.
`foldedAt(line)` cannot be stale by construction, so its resolution path is
unchanged.

### 2. `lib/src/code_field/code_controller.dart` — `foldBlocks`

```dart
/// Folds [blocks] in one pass: one new `Code`, one value assignment, one
/// listener notification, regardless of how many blocks are folded.
///
/// Blocks that are already folded, or that the current code no longer
/// holds, are skipped. When nothing remains to fold no value is assigned.
void foldBlocks(Iterable<FoldableBlock> blocks) {
  var newCode = _code;

  for (final block in blocks) {
    newCode = newCode.foldedBlock(block);
  }

  if (identical(newCode, _code)) {
    return;
  }

  super.value = _getValueWithCode(newCode);
  _code = newCode;
}
```

Each iteration folds into the previous result, so the N-th block builds on
N−1 folds inside one `Code`; the user-visible assignment happens once, after
the loop. Selection recovery goes through the same `_getValueWithCode`, so the
final selection is exactly the one the last `foldAt` in a loop would produce —
the intermediate cuts are the states being removed.

### 3. The two batch helpers delegate

```dart
void foldImports() {
  foldBlocks(_code.foldableBlocks.where((block) => block.isImports));
}
```

`foldOutsideSections` keeps its line-set computation verbatim — it encodes
"one fold per first line, first matching block" — and resolves each surviving
line to its block the way `_getFoldableBlockByStartLine` does (first match in
`foldableBlocks`; `foldedBlocks ⊆ foldableBlocks`, so the resolution is the
same instance):

```dart
foldBlocks(
  foldLines
      .map((line) =>
          _code.foldableBlocks.firstWhereOrNull((b) => b.firstLine == line))
      .whereType<FoldableBlock>(),
);
```

Both upstream TODOs ("An optimized method to fold multiple blocks",
akvelon/flutter-code-editor#106) are removed.

### Why this shape and not the alternatives

- **Not `Code.foldedAll(Iterable)` doing the whole loop.** Keeping the loop in
  the controller keeps the "one value assignment" policy next to the other
  assignment policy (`foldAt`), and keeps `Code`'s new surface a single
  symmetric method next to `foldedAt`/`unfoldedAt`.
- **Not folding by line in the batch.** A `firstLine` can name a position the
  caller believes is a fold start when the current parse disagrees; a block
  object cannot lie about its own currency — the `foldableBlocks.contains`
  guard checks it.
- **Not batching `unfoldAt` too.** Nothing in the package loops unfold; the
  spec scopes it out.

## Order of work

1. `test/src/code_field/code_controller_fold_blocks_test.dart` — new tests:
   identical-code-to-loop (A1), one assignment + one notification (A2),
   already-folded and stale blocks skipped (A3), selection recovery matches
   the single-fold path (A5). Red.
2. `Code.foldedBlock` + `foldedAt` delegation — A1, A3, A5 green.
3. `CodeController.foldBlocks` — A2 green.
4. Delegate `foldImports`/`foldOutsideSections`, drop the TODOs; the existing
   `code_controller_folding_test.dart` suite is the characterization guard
   (A4) and must stay green untouched.
5. Full suite, analyze/format, coverage gate (A6).

## Risks

- **`foldOutsideSections` line→block resolution.** Resolving through
  `foldableBlocks` first-match instead of `_getFoldableBlockByStartLine`
  (folded-first) differs only if a folded block can sit at a first line whose
  foldable block is a different object — impossible while `foldedBlocks ⊆
  foldableBlocks`. The folding-editing suite (`code_controller_folding_editing_test.dart`)
  re-parses code between folds and is the guard.
- **The zero-assignment skip.** When every given block is already folded or
  stale, no value is assigned — today `foldAt` in a loop would still assign
  N idempotent values (visible text unchanged, but the selection is re-cut
  through `_getValueWithCode` each time). The skip is the optimization itself;
  pinned by an A2 variant test so the behavior is deliberate.
- **`identical(newCode, _code)` as the change detector.** `foldedBlock`
  returns `this` on every skip and a fresh instance on every real fold, so
  identity is exact. Pinned by the A2 tests.
- **EXEMPT_LINES line numbers.** The gate pins lines by number; count
  insertions in the touched files before running it.
