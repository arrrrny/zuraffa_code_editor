import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../code_field/code_controller.dart';
import '../sizes.dart';

/// Tints the background of individual code lines.
///
/// Rendered behind the editor's text, one row per **visible** line, so a tint
/// covers the whole width of the line's row rather than the extent of its text
/// — a short line is tinted across the whole row, not only as far as its last
/// character.
///
/// The rows are the same rows the gutter renders: the visible line numbers in
/// iteration order, at the heights the field measured for the gutter (or one
/// line high when the editor does not wrap), so the tint lands on the line it
/// labels through wraps and folds.
///
/// Only built when `CodeController.lineBackgroundBuilder` is set; with it null
/// the layer is not in the tree at all.
@internal
class LineBackgroundLayer extends StatelessWidget {
  final CodeController controller;

  /// Height of each visible line's row, top to bottom. Exactly one entry per
  /// visible line, in the same order as
  /// `controller.code.hiddenLineRanges.visibleLineNumbers` — the field that
  /// builds the list guarantees it, which is what lets [build] index both
  /// directly.
  final List<double> rowHeights;

  const LineBackgroundLayer({
    super.key,
    required this.controller,
    required this.rowHeights,
  });

  @override
  Widget build(BuildContext context) {
    final builder = controller.lineBackgroundBuilder;
    final currentLineColor = controller.currentLineColor;
    if (builder == null && currentLineColor == null) {
      return const SizedBox.shrink();
    }

    final currentLineIndex = _caretLineIndex(controller);
    final visibleLines = controller.code.hiddenLineRanges.visibleLineNumbers
        .toList();

    return Padding(
      // The gutter's own outer padding, so the tint starts where the text does.
      padding: const EdgeInsets.symmetric(vertical: codeFieldVerticalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(visibleLines.length, (row) {
          final line = visibleLines[row];
          final color =
              builder?.call(line) ??
              (line == currentLineIndex ? currentLineColor : null);

          if (color == null) {
            return SizedBox(height: rowHeights[row]);
          }

          return Container(color: color, height: rowHeights[row]);
        }),
      ),
    );
  }
}

/// The line the caret is on, as an index in the full, unfolded buffer, or -1
/// when there is no caret in range to tint.
///
/// A `RangeError` thrown from a `build` method takes the whole editor with it,
/// and `CodeLines.characterIndexToLineIndex` throws outside
/// `[0, text.length]`. Three real caret states sit at or beyond that boundary:
/// the `-1` offset an untouched `TextEditingValue` carries, a caret past the
/// text while `Code` catches up with an edit, and — the one that must *not* be
/// rejected — a caret at exactly `text.length`, which the helper documents as
/// "the cursor at the end of the text" and which belongs to the last line.
///
/// -1 is used as the "none" sentinel because it can never equal a visible line
/// number, so the comparison in [build] needs no extra branch.
int _caretLineIndex(CodeController controller) {
  final text = controller.code.text;
  final offset = controller.selection.extentOffset;
  if (offset < 0 || offset > text.length) {
    return -1;
  }

  return controller.code.lines.characterIndexToLineIndex(offset);
}
