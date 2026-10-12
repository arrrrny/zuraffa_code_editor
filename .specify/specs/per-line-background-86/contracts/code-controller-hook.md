# Contract: `CodeController.lineBackgroundBuilder`

The single public surface this feature adds. Nothing else in the package's public
API changes.

## Signature

```dart
/// Tints the background of individual lines.
///
/// Called once per rendered line with the line's index in the full, unfolded
/// buffer — 0-based, the same coordinate space as [Issue.line] and
/// [FoldableBlock.firstLine]. Return the colour to tint that line's row with,
/// or null to leave it untinted.
///
/// Left null, the editor renders exactly as it did before this field existed:
/// no background layer is built and no span carries a background.
///
/// The tint covers the full width of the line's row, including the stretch
/// past the last character, and it sits behind the editor's search-match
/// highlighting, which still wins on a matched run.
///
/// Lines inside a folded block or a hidden section are not rendered, so the
/// builder is not called for them.
///
/// Reassign this and notify listeners to re-render — for example to follow the
/// cursor:
///
/// ```dart
/// controller.lineBackgroundBuilder = (line) =>
///     line == controller.selection.base.offset ? Colors.yellow : null;
/// controller.notifyListeners();
/// ```
final Color? Function(int lineIndex)? lineBackgroundBuilder;
```

## Guarantees

1. **Default is a no-op.** `lineBackgroundBuilder == null` produces the same
   widget tree and the same `TextSpan` tree as before, on both the language and
   the no-language path. No extra widget is built and no span is re-styled.
2. **Per rendered line, exactly once.** The builder is called at most once per
   rendered line per build. A line that is not rendered is never passed.
3. **Full-row extent.** The tint's width is the line's row width, not the width
   of its text. A line one character long is tinted across the whole row.
4. **Correct index under every transform.** The index is the full, unfolded
   index, correct with folds open, with hidden sections, with a multi-line
   highlight node over the line, and with a trailing newline.
5. **No text is synthesized.** The builder cannot and must not affect the text
   the editor edits. Caret position, selection, hit-testing and every existing
   text assertion are unchanged.
6. **Behind search highlighting.** On a line with both a tint and an active
   search match, matched runs keep the search colour; the rest of the row keeps
   the tint.
7. **No new export, no new public type.** The field lives on `CodeController`,
   which is already exported from `lib/zuraffa_code_editor.dart`.

## Non-guarantees (explicitly out of contract)

- The tint is a background colour only: no border, no text colour, no gradient.
- It covers whole lines. A host that wants to tint a sub-line range needs a
  different feature.
- The gutter's own cells are not affected. Per-line gutter styling is
  `GutterStyle`'s concern.

## Consumers this unblocks

- #113 — highlight the cursor line (a host assigns the hook from
  `controller.selection`).
- Search-hit line tinting, error-line tinting — both are host-side
  assignments of the same hook.
