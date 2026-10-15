# Bug Issue: hidden ranges of a folded block are lost when a following newline is deleted

- **Slug**: fold-hidden-range-lost-on-newline-delete
- **Fetched**: 2026-10-13
- **Issue**: akvelon/flutter-code-editor#175
- **URL**: https://github.com/akvelon/flutter-code-editor/issues/175
- **State**: open
- **Severity**: unknown
- **Author**: yescorp
- **Labels**: none

## Body

Verbatim upstream body:

```
Hidden ranges of folded foldable block gets removed when you delete one of the
consecutive new line chars after the block

This is surely a bug.

https://user-images.githubusercontent.com/79095619/216600459-8ab7d175-e9ae-4b22-a5d7-8a603a08030e.mov
```

The reporter's app is a `CodeField` with a folded foldable block and a run of
blank lines after it. The video shows the block's fold marker disappearing and
the hidden content rendering back in after deleting one of the blank lines'
newline characters.

## Why it matters

A fold is the user's statement that a region should stay collapsed. Deleting an
*adjacent* newline is not a statement about that region, yet it makes the fold
vanish — and the hidden content floods back into view, which is the one
outcome the reporter folded to avoid. On a large file that means hundreds of
lines reappearing from a single keystroke.

## Acceptance criteria

- [x] Reproducing widget test: fold a block, select the newline that ends its
      closer row, delete it → the block stays folded, its hidden range
      survives, the visible text loses exactly that newline.
- [x] The block's hidden content never becomes visible as a result, and the
      block stays unfoldable afterwards.
- [x] Existing folding-editing tests stay green, especially
      `test/src/code_field/code_controller_folding_editing_test.dart`'s
      "Deleting folded blocks" group and the #108 identical-block test.
- [x] 100% line coverage maintained on the touched files.

## Comments

None.

## Reproduction note

The literal keystroke (Backspace/Delete) path is already covered by the guard
upstream added for #222 (`code.dart:492`), which refuses a collapsed
single-character deletion that would remove a folded block. That guard's whole
contract is one test — `Code.getEditResult keeps text on backspace into a
folded block`. **#175 still reproduces on master through a selection edit**,
which the guard does not cover (it is keyed on `oldSelection.isCollapsed`), so
the defect is real and is what the fix addresses.
