# Spec: fold survives a deletion of a newline next to it (#175)

## Problem

`FoldableBlockMatcher._editTouchedHiddenContent` drops a folded block when it
believes the edit replaced lines the block hides. It computes that span as
`block.firstLine + 1 .. block.lastLine`, treating the block's **last line** as
hidden content.

It is not. `Code.foldableBlockToHiddenRange` deliberately ends the range at the
closer row's *start* so the closer stays on screen, so the closer row — and the
newline that ends it, which is the first character of the line below the fold —
is visible content. An edit that removes that newline, or one of the blank lines
under it, changes nothing the fold hides, yet the predicate fires and the fold
is dropped: the hidden content renders back in and the fold marker disappears.

Over-reach introduced by our own #108 fix (`6c9fa1a`), when `changedOldLines`
was threaded into the matcher.

## Invariant to restore

An edit that touches only rows the fold leaves on screen — the block's own
closer row, or a blank row after it — leaves the fold alone. Only an edit that
reaches into the block's hidden content can unfold it.

## Rules

- **R1 — the closer row is visible content, not hidden.** An edit whose changed
  region covers the block's last line but not the lines the fold hides must
  keep the block folded. This is the #175 case.
- **R2 — the block's first line counts.** The hidden range starts on the newline
  ending the block's first line, so the first line is part of the span an edit
  must not enter. This is the #108 case: for a two-line block whose closer is
  the next row, the whole hidden content is that newline, and an edit starting
  on the first line must drop the fold.
- **R3 — a content line is hidden whole.** When the block's last line is not a
  closing line (the tail of a `//` comment block, a continued argument) it is
  hidden through its end, so an edit on that line still drops the fold.
- **R4 — the fold stays unfoldable.** A block that survives a deletion next to
  it must still unfold, revealing exactly the hidden content that survived.

## What is not in scope

- The #222 guard (`code.dart:492`) and `Code.getEditResult`'s affinity logic.
  The guard is keyed on `oldSelection.isCollapsed` and single-character
  deletions; it already refuses the collapsed Backspace that would remove a
  folded block, and both it and `_editStartAffinity` are pinned by
  `code_get_edit_result_test.dart` and `code_controller_set_value_test.dart`.
  Neither is touched.
- `changedOldLines` itself, and the matcher's content comparison in
  `_addIfMatch`.

## Acceptance

- Deleting the newline that ends a folded block's closer row keeps the block
  folded, shortens the visible text by exactly one newline, and keeps the
  hidden content hidden.
- Deleting a blank line further away keeps the fold too (guard against
  over-fixing).
- The block is still unfoldable afterwards and reveals the content that
  survived the edit.
- #108's identical-block transfer test stays green: deleting the folded one of
  two identical blocks must not transfer the fold to the other.
- `flutter test` fully green, `dart analyze --fatal-infos` clean, 100% line
  coverage gate green.
