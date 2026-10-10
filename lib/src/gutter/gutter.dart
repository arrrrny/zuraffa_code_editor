import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../code_field/code_controller.dart';
import '../line_numbers/gutter_style.dart';
import '../sizes.dart';
import 'error.dart';
import 'fold_toggle.dart';

const _issueColumnWidth = 16.0;
const _foldingColumnWidth = 16.0;

const _lineNumberColumn = 0;
const _issueColumn = 1;
const _foldingColumn = 2;

class GutterWidget extends StatelessWidget {
  const GutterWidget({
    super.key,
    required this.codeController,
    required this.style,
    required this.scrollController,
    this.rowHeights,
  });

  final CodeController codeController;
  final GutterStyle style;
  final ScrollController? scrollController;

  /// Rendered height of every visible row, indexed by row (not by line).
  ///
  /// Null when the editor does not wrap: there every row is exactly one text
  /// line high, which the shared text style already pins. When the editor
  /// wraps, a logical line occupies several visual rows, so the gutter rows
  /// must follow or the gutter's scroll extent no longer matches the code's
  /// and the numbers drift off their lines.
  final List<double>? rowHeights;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: codeFieldVerticalPadding),
      child: Padding(
        // User escape hatch for fine gutter alignment: applied outside the
        // columns so the whole number/error/folding grid shifts by exactly
        // these insets. Zero by default — renders like no padding at all.
        padding: style.padding,
        child: SingleChildScrollView(
          controller: scrollController,
          child: AnimatedBuilder(
            animation: codeController,
            builder: _buildOnChange,
          ),
        ),
      ),
    );
  }

  Widget _buildOnChange(BuildContext context, Widget? child) {
    final code = codeController.code;

    final issueColumnWidth = style.showErrors ? _issueColumnWidth : 0.0;
    final foldingColumnWidth = style.showFoldingHandles
        ? _foldingColumnWidth
        : 0.0;

    // The numbers are a flex column, so they take whatever the requested width
    // leaves after the fixed columns and the margin to the code — and never
    // less than the widest visible number needs to render on one line. A
    // number that does not fit wraps, and a wrapped number is twice as tall as
    // the line it labels: every row past it doubles in pitch, the gutter's
    // scroll extent stops matching the code's, and the rows on screen end up
    // with no number over them (#18).
    final numberColumnWidth = math.max(
      style.width - issueColumnWidth - foldingColumnWidth - style.margin,
      _widestNumberWidth(),
    );

    final tableRows = List.generate(
      code.hiddenLineRanges.visibleLineNumbers.length,
      (i) => TableRow(
        // ignore: prefer_const_literals_to_create_immutables
        children: [
          _sized(const SizedBox(), i),
          _sized(const SizedBox(), i),
          _sized(const SizedBox(), i),
        ],
      ),
    );

    _fillLineNumbers(tableRows);

    if (style.showErrors) {
      _fillIssues(tableRows);
    }
    if (style.showFoldingHandles) {
      _fillFoldToggles(tableRows);
    }

    return Container(
      padding: EdgeInsets.only(right: style.margin),
      width: style.showLineNumbers
          ? issueColumnWidth +
                foldingColumnWidth +
                style.margin +
                numberColumnWidth
          : null,
      child: Table(
        columnWidths: {
          _lineNumberColumn: FlexColumnWidth(),
          _issueColumn: FixedColumnWidth(issueColumnWidth),
          _foldingColumn: FixedColumnWidth(foldingColumnWidth),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: tableRows,
      ),
    );
  }

  /// Width the widest visible line number needs to render on a single line.
  ///
  /// Zero when the numbers are hidden, or when there is nothing to number, so
  /// the requested width is left untouched in both cases.
  double _widestNumberWidth() {
    if (!style.showLineNumbers) {
      return 0.0;
    }

    var widest = -1;
    for (final number
        in codeController.code.hiddenLineRanges.visibleLineNumbers) {
      if (number > widest) {
        widest = number;
      }
    }
    if (widest < 0) {
      return 0.0;
    }

    final painter = TextPainter(
      text: TextSpan(text: '${widest + 1}', style: style.textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  void _fillLineNumbers(List<TableRow> tableRows) {
    final code = codeController.code;

    for (final i in code.hiddenLineRanges.visibleLineNumbers) {
      final lineIndex = _lineIndexToTableRowIndex(i);

      if (lineIndex == null) {
        continue;
      }

      tableRows[lineIndex].children[_lineNumberColumn] = _sized(
        Text(
          style.showLineNumbers ? '${i + 1}' : ' ',
          style: style.textStyle,
          textAlign: style.textAlign,
          // A single line, always: a wrapped number is twice as tall as the
          // line it labels, which is the #18 desync. The column is sized to
          // fit the widest number, so this never clips in practice.
          softWrap: false,
          maxLines: 1,
        ),
        lineIndex,
      );
    }
  }

  void _fillIssues(List<TableRow> tableRows) {
    for (final issue in codeController.analysisResult.issues) {
      if (issue.line >= codeController.code.lines.length) {
        continue;
      }

      final lineIndex = _lineIndexToTableRowIndex(issue.line);
      if (lineIndex == null || lineIndex >= tableRows.length) {
        continue;
      }
      tableRows[lineIndex].children[_issueColumn] = _sized(
        GutterErrorWidget(
          issue,
          style.errorPopupTextStyle ??
              (throw Exception('Error popup style should never be null')),
        ),
        lineIndex,
      );
    }
  }

  void _fillFoldToggles(List<TableRow> tableRows) {
    final code = codeController.code;

    for (final block in code.foldableBlocks) {
      final lineIndex = _lineIndexToTableRowIndex(block.firstLine);
      if (lineIndex == null) {
        continue;
      }

      final isFolded = code.foldedBlocks.contains(block);

      tableRows[lineIndex].children[_foldingColumn] = _sized(
        FoldToggle(
          color: style.textStyle?.color,
          isFolded: isFolded,
          onTap: isFolded
              ? () => codeController.unfoldAt(block.firstLine)
              : () => codeController.foldAt(block.firstLine),
        ),
        lineIndex,
      );
    }

    // Add folded blocks that are not considered as a valid foldable block,
    // but should be folded because they were folded before becoming invalid.
    for (final block in code.foldedBlocks) {
      final lineIndex = _lineIndexToTableRowIndex(block.firstLine);
      if (lineIndex == null || lineIndex >= tableRows.length) {
        continue;
      }

      tableRows[lineIndex].children[_foldingColumn] = _sized(
        FoldToggle(
          color: style.textStyle?.color,
          isFolded: true,
          onTap: () => codeController.unfoldAt(block.firstLine),
        ),
        lineIndex,
      );
    }
  }

  int? _lineIndexToTableRowIndex(int line) {
    return codeController.code.hiddenLineRanges.cutLineIndexIfVisible(line);
  }

  /// Pins [child]'s row to the height its code line renders at.
  ///
  /// A no-op unless wrapping row heights were handed in, so the unwrapped
  /// layout — and every snapshot of it in the tests — is untouched.
  Widget _sized(Widget child, int rowIndex) {
    final height = rowHeights?.elementAtOrNull(rowIndex);
    if (height == null) {
      return child;
    }
    return SizedBox(height: height, width: double.infinity, child: child);
  }
}
