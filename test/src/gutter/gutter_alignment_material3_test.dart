import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import 'gutter_alignment_harness.dart';

/// Upstream #262 / fork #28: "Material 3 causes progressive misalignment
/// between code and line numbers".
///
/// The report is specific about the reproduction: the same document is either
/// aligned or *equally* misaligned under Material 2, and only
/// `ThemeData(useMaterial3: true)` makes the two grids drift apart further on
/// every line. That rules out the alignment logic itself and points at
/// something theme-derived — and indeed the only theme value the editor reads
/// is `textTheme.titleMedium`, from which `CodeField` takes `fontSize` *and*
/// `height` for the code's line box.
///
/// The fix that landed here (`CodeField._buildGutter()` copying `height`
/// alongside `fontSize` and `fontFamily`, commit 8d11ce7) makes the gutter's
/// row height derive from exactly the style the editor renders with, so the
/// two grids stay one grid. These tests pin that invariant under Material 3,
/// and — the case that actually detects the regression — when the caller
/// supplies a `gutterStyle.textStyle` of their own that omits `height`,
/// where the gutter would otherwise fall back to the font's own metrics.
void main() {
  testWidgets('Material 3: unfolded gutter shares the code line grid', (
    wt,
  ) async {
    final controller = await pumpGutterAlignmentEditor(wt, useMaterial3: true);

    // Guard the reproduction itself: Material 3 must actually hand the editor
    // a `height`, or nothing here distinguishes it from Material 2.
    expectEditorLineHeightSet(wt, controller);

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
      state: 'M3 unfolded',
    );
  });

  testWidgets('Material 3: folded gutter still shares the code line grid', (
    wt,
  ) async {
    final controller = await pumpGutterAlignmentEditor(wt, useMaterial3: true);

    expectEditorLineHeightSet(wt, controller);

    controller.foldAt(1); // `  void m() {`
    controller.foldAt(13); // `  void n() {`
    await wt.pump();

    final lineH = renderedLineHeight(wt, controller);
    final rows = gutterRows(wt, controller);
    expect(rows.length, 15);

    expectOnGrid(
      rows,
      top: textTop(wt, controller),
      lineHeight: lineH,
      state: 'M3 folded',
    );
  });

  /// The case that actually detects a regression.
  ///
  /// `_buildGutter()` resolves its style as
  /// `(widget.gutterStyle.textStyle ?? textStyle)`. When the caller passes a
  /// gutter style of their own that omits `height` — the common case, because
  /// `GutterStyle.textStyle` documents only colour as meaningful — the gutter's
  /// rows would fall back to the font's own metrics. Dropping the
  /// `height: textStyle.height` line from `_buildGutter()` makes this fail with
  /// a one-pixel-per-row drift (23 against 24 measured), i.e. the progressive
  /// misalignment the issue reports.
  testWidgets(
    'Material 3: a gutter style without height still lands on the code grid',
    (wt) async {
      final controller = await pumpGutterAlignmentEditor(
        wt,
        useMaterial3: true,
        // Only non-nullness matters: `_buildGutter()` overrides fontFamily,
        // fontSize and color off the editor's own style. `height` is
        // deliberately omitted — that is the case under test.
        gutterStyle: const GutterStyle(textStyle: TextStyle()),
      );

      expectEditorLineHeightSet(wt, controller);

      final lineH = renderedLineHeight(wt, controller);
      final rows = gutterRows(wt, controller);
      expect(rows.length, 37);

      expectOnGrid(
        rows,
        top: textTop(wt, controller),
        lineHeight: lineH,
        state: 'M3 custom gutter style',
      );
    },
  );
}
