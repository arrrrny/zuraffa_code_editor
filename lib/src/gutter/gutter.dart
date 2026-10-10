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

    final gutterWidth =
        style.width -
        (style.showErrors ? 0 : _issueColumnWidth) -
        (style.showFoldingHandles ? 0 : _foldingColumnWidth);

    final issueColumnWidth = style.showErrors ? _issueColumnWidth : 0.0;
    final foldingColumnWidth = style.showFoldingHandles
        ? _foldingColumnWidth
        : 0.0;

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
      width: style.showLineNumbers ? gutterWidth : null,
      child: Table(
        columnWidths: {
          _lineNumberColumn: const FlexColumnWidth(),
          _issueColumn: FixedColumnWidth(issueColumnWidth),
          _foldingColumn: FixedColumnWidth(foldingColumnWidth),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: tableRows,
      ),
    );
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
