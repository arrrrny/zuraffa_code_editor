# Assessment: identical-folded-blocks-108

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/108
(upstream akvelon/flutter-code-editor#83).

## Severity

Low (as filed): the user-visible effect is a block folded without a user
action, and it is recoverable with one fold toggle. The rank-11 backlog
position matches.

## Root cause

Reproduced at the controller level. Two textually identical blocks:

```dart
void a() {
  int x = 1;
}
void a() {
  int x = 1;
}
```

Folding block 0 (`controller.foldAt(0)`), then selecting and deleting the
folded block, leaves `foldedBlocks == {FoldableBlock(0, 2, braces)}` — the
fold transferred to the surviving block, exactly as reported.

`FoldableBlockMatcher` re-matches the folds after every edit. Its
`_addIfMatch` decides a fold survived by comparing the fold's **hidden
content lines** with the new block's content. Two textually identical blocks
have identical hidden content, so when the folded block is deleted the matcher
finds the surviving block by its content and re-attaches the fold to it. The
folded block's own first (visible) line is compared too, but it is excluded
from that comparison, so it cannot disambiguate.

Confirmed it is not a diff/line-index bug: the fold's stored line indices do
matter — the matcher only reaches the content comparison for blocks at or
after the edit.

## Where it lives

`lib/src/folding/foldable_block_matcher.dart` (`_addIfMatch`), fed by
`lib/src/code/code.dart` (`Code.foldedAs`) and `lib/src/code_field/code_controller.dart`
(`_updateCodeIfChanged` → `_updateCode`).

## Fix direction

Thread the edit's changed old-line range into the matcher and require that an
edit left the fold's hidden content untouched: the first hidden line
(`firstLine + 1`) must not overlap the changed old-line range. The block's own
first line stays exempt so an edit on the visible line still keeps the fold
(that is the branch that keeps caret-on-opener edits working). No new public
API beyond the optional `TextRange? changedOldLines` parameter.
