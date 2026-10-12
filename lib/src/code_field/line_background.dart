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
    if (builder == null) {
      return const SizedBox.shrink();
    }

    final visibleLines = controller.code.hiddenLineRanges.visibleLineNumbers
        .toList();

    return Padding(
      // The gutter's own outer padding, so the tint starts where the text does.
      padding: const EdgeInsets.symmetric(vertical: codeFieldVerticalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(visibleLines.length, (row) {
          final color = builder(visibleLines[row]);

          if (color == null) {
            return SizedBox(height: rowHeights[row]);
          }

          return Container(color: color, height: rowHeights[row]);
        }),
      ),
    );
  }
}
