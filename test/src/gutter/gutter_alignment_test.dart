import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gutter_alignment_harness.dart';

/// Regression: gutter rows must be laid out on the code's line grid.
///
/// `CodeField._buildGutter()` copies the code style's `fontSize` and
/// `fontFamily` into the gutter style explicitly "for consistency with
/// lines", but it used to leave out `height`. Gutter rows then fell back to
/// the font's own line metrics and so were a few pixels shorter than the code
/// line they labelled. The two grids drifted apart by that difference on
/// every single line — around 60px by line 36 of a typical file, and visibly
/// worse once blocks were folded, because the fold chevron is centred in its
/// gutter row and so inherited the drift.
///
/// This pins the invariant in both states: the gutter starts on the text's
/// top edge and every row is exactly one rendered code line tall.
void main() {
  testWidgets('Unfolded gutter shares the code line grid', (wt) async {
    final controller = await pumpGutterAlignmentEditor(
      wt,
      textStyle: const TextStyle(
        fontSize: 13,
        height: 1.6,
        fontFamily: 'JetBrainsMono',
      ),
    );

    final lineH = renderedLineHeight(wt, controller);
    final rows = gutterRows(wt, controller);

    // 36 source lines plus the trailing empty line after the final '\n'.
    expect(
      rows.length,
      37,
      reason: 'every source line, trailing empty one included, gets a row',
    );

    expectOnGrid(
      rows,
      top: textTop(wt, controller),
      lineHeight: lineH,
      state: 'Unfolded',
    );
  });

  testWidgets('Folded gutter still shares the code line grid', (wt) async {
    final controller = await pumpGutterAlignmentEditor(
      wt,
      textStyle: const TextStyle(
        fontSize: 13,
        height: 1.6,
        fontFamily: 'JetBrainsMono',
      ),
    );

    controller.foldAt(1); // `  void m() {` — 10 body lines + its closer line.
    controller.foldAt(13); // `  void n() {`.
    await wt.pump();

    final lineH = renderedLineHeight(wt, controller);
    final rows = gutterRows(wt, controller);

    // 37 - 11 - 11. Each fold drops its 10 body rows *and* the closer's own
    // row: the closer's text is appended to the opener's row (`void m() {  }`)
    // so it stays on screen without claiming a gutter row of its own.
    expect(
      rows.length,
      15,
      reason: 'each fold merges 10 body lines plus its closer into the opener',
    );

    expectOnGrid(
      rows,
      top: textTop(wt, controller),
      lineHeight: lineH,
      state: 'Folded',
    );
  });
}
