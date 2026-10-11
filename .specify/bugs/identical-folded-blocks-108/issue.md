# Issue: Deleting one of two identical folded blocks folds the other

- **Number**: 108
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/108
- **Upstream**: https://github.com/akvelon/flutter-code-editor/issues/83
- **Labels**: bug, severity:low
- **Backlog rank**: 11
- **Created**: 2026-10-10

## What is wrong / missing (as filed)

Fold state transfers between two textually identical but distinct blocks.

## Where it lives (as filed)

`lib/src/folding/foldable_block.dart`

## Reproduction (as filed)

Fold one of two textually identical blocks, then delete the folded one — the
surviving identical block ends up folded, though the user never folded it.
