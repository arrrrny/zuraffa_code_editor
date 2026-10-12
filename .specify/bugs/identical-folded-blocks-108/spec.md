# Spec: identical-folded-blocks-108

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/108
(upstream akvelon/flutter-code-editor#83).

## Requirement

When an edit deletes or replaces a folded block, the fold is dropped with that
block — it must not transfer to another, textually identical block. A folded
block survives an edit that touches neither its hidden content nor (for the
block it belongs to) its own first line, exactly as before.

## Acceptance

- Deleting the folded block of two textually identical blocks leaves
  `foldedBlocks` empty and the surviving block fully visible.
- A folded block survives an edit anywhere well away from it.
- A folded block survives an edit on its own first (visible) line.
- A folded block does not survive a change of its hidden content.
- The behaviour of the pre-existing "deleting 2nd identical folded block"
  test flips from the documented incorrect fold to no fold, with the full text
  in the value.
- Coverage gate unchanged at 100%.

## Non-goals

- Changing how folds are matched when nothing was folded (the new parameter is
  optional and that path is untouched).
- Any UI change: the fold widget, toggles and gutter are not involved.
