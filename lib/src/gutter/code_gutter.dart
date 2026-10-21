import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:re_editor/re_editor.dart';

import '../analyzer/models/issue.dart';
import '../code_field/code_controller.dart';
import '../line_numbers/gutter_style.dart';

const double _kIssueColumnWidth = 16.0;
const double _kFoldingColumnWidth = 16.0;

/// The gutter of the re_editor-backed code field.
///
/// The gutter is a leaf render object rather than a column of widgets: the
/// editor hands it the paragraphs it has actually laid out, which are the
/// ones on screen, so a document of any length costs the same to draw as a
/// document of one screen.
///
/// The line numbers are the document's own, not the editor's: a fold cuts
/// lines out of the text the editor renders, so the editor's line index and
/// the document's line index part company as soon as anything is folded, and
/// the gutter resolves the difference through the controller's hidden line
/// ranges.
class CodeGutter extends LeafRenderObjectWidget {
  const CodeGutter({
    super.key,
    required this.codeController,
    required this.notifier,
    required this.style,
    required this.codeTextStyle,
  });

  /// The controller that owns the document, its folds and its analysis.
  final CodeController codeController;

  /// The notifier the editor publishes its laid out paragraphs through.
  final CodeIndicatorValueNotifier notifier;

  /// The style of the gutter.
  final GutterStyle style;

  /// The style of the code the gutter labels.
  ///
  /// The gutter's rows have to be exactly as tall as the code's lines, so the
  /// numbers are drawn with the code's own metrics: the font size, the face
  /// and the line height are taken from here.
  final TextStyle codeTextStyle;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return CodeGutterRenderObject(
      codeController: codeController,
      notifier: notifier,
      style: style,
      codeTextStyle: codeTextStyle,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant CodeGutterRenderObject renderObject,
  ) {
    renderObject
      ..codeController = codeController
      ..notifier = notifier
      ..style = style
      ..codeTextStyle = codeTextStyle;
  }
}

/// The render object of a [CodeGutter].
class CodeGutterRenderObject extends RenderBox {
  CodeGutterRenderObject({
    required CodeController codeController,
    required CodeIndicatorValueNotifier notifier,
    required GutterStyle style,
    required TextStyle codeTextStyle,
  }) : _codeController = codeController,
       _notifier = notifier,
       _style = style,
       _codeTextStyle = codeTextStyle,
       _numberPainter = TextPainter(textDirection: TextDirection.ltr),
       _iconPainter = TextPainter(textDirection: TextDirection.ltr) {
    _notifier.addListener(markNeedsPaint);
    _codeController.addListener(_onControllerChanged);
  }

  CodeController _codeController;
  CodeIndicatorValueNotifier _notifier;
  GutterStyle _style;
  TextStyle _codeTextStyle;

  final TextPainter _numberPainter;
  final TextPainter _iconPainter;

  set codeController(CodeController value) {
    if (_codeController == value) {
      return;
    }
    _codeController.removeListener(_onControllerChanged);
    _codeController = value;
    _codeController.addListener(_onControllerChanged);
    markNeedsPaint();
  }

  set notifier(CodeIndicatorValueNotifier value) {
    if (_notifier == value) {
      return;
    }
    _notifier.removeListener(markNeedsPaint);
    _notifier = value;
    _notifier.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set style(GutterStyle value) {
    if (_style == value) {
      return;
    }
    _style = value;
    markNeedsLayout();
  }

  set codeTextStyle(TextStyle value) {
    if (_codeTextStyle == value) {
      return;
    }
    _codeTextStyle = value;
    markNeedsLayout();
  }

  @override
  void attach(covariant PipelineOwner owner) {
    _codeController.addListener(_onControllerChanged);
    _notifier.addListener(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _codeController.removeListener(_onControllerChanged);
    _notifier.removeListener(markNeedsPaint);
    super.detach();
  }

  void _onControllerChanged() {
    if (attached) {
      markNeedsPaint();
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_onControllerChanged);
    _notifier.removeListener(markNeedsPaint);
    _numberPainter.dispose();
    _iconPainter.dispose();
    super.dispose();
  }

  double get _issueColumnWidth => _style.showErrors ? _kIssueColumnWidth : 0.0;

  double get _foldingColumnWidth =>
      _style.showFoldingHandles ? _kFoldingColumnWidth : 0.0;

  /// The width the number column takes.
  ///
  /// The numbers are the flexible column: they take whatever the requested
  /// width leaves after the fixed columns and the margin to the code, and
  /// never less than the widest visible number needs to render on one line.
  double get _numberColumnWidth {
    if (!_style.showLineNumbers) {
      return 0.0;
    }

    return math.max(
      _style.width - _issueColumnWidth - _foldingColumnWidth - _style.margin,
      _widestNumberWidth(),
    );
  }

  /// Width the widest visible line number needs to render on a single line.
  double _widestNumberWidth() {
    final numbers = _codeController.code.hiddenLineRanges.visibleLineNumbers;
    if (numbers.isEmpty) {
      return 0.0;
    }

    _numberPainter.text = TextSpan(
      text: '${numbers.last + 1}',
      style: _numberStyle,
    );
    _numberPainter.layout();
    final width = _numberPainter.width;
    _numberPainter.text = const TextSpan(text: '');
    return width;
  }

  /// The style the numbers are drawn with.
  ///
  /// The numbers are drawn with the code's own metrics — the font size, the
  /// face and the line height — so a gutter row is exactly as tall as the
  /// line it labels. Without the code's line height each row falls back to
  /// the font's own metrics, and the two grids drift apart by that
  /// difference on every line.
  TextStyle get _numberStyle {
    final style = _style.textStyle ?? _codeTextStyle;
    return style.copyWith(
      color:
          _style.textStyle?.color ??
          _codeTextStyle.color?.withValues(alpha: .5),
      fontFamily: _codeTextStyle.fontFamily,
      fontSize: _codeTextStyle.fontSize,
      height: _codeTextStyle.height,
    );
  }

  @override
  void performLayout() {
    assert(
      constraints.maxHeight > 0 && constraints.maxHeight != double.infinity,
      'The gutter needs an explicit height.',
    );

    final width =
        _numberColumnWidth +
        _issueColumnWidth +
        _foldingColumnWidth +
        _style.margin;
    size = Size(width, constraints.maxHeight);
  }

  /// The number the gutter shows on the visible row [visibleRow].
  ///
  /// The rows the editor renders are the visible ones — a fold cuts the lines
  /// it covers out of the text — so the number on a row is the number of the
  /// document line that row stands for, not the row's own index.
  ///
  /// Null when the row is not on the document.
  String? numberForVisibleRow(int visibleRow) {
    final numbers = _codeController.code.hiddenLineRanges.visibleLineNumbers;
    if (visibleRow < 0 || visibleRow >= numbers.length) {
      return null;
    }

    return '${numbers.elementAt(visibleRow) + 1}';
  }

  /// The position of the folding toggle of the visible row [visibleRow].
  ///
  /// Null when the row is not on the screen.
  Offset? foldingTogglePosition(int visibleRow) {
    final paragraphs = _notifier.value?.paragraphs;
    if (paragraphs == null) {
      return null;
    }

    for (final paragraph in paragraphs) {
      if (paragraph.index != visibleRow) {
        continue;
      }

      final left =
          _numberColumnWidth + _issueColumnWidth + _foldingColumnWidth / 2;
      return Offset(left, paragraph.offset.dy + _rowHeight / 2);
    }

    return null;
  }

  /// The position of the folding toggle of the block that starts at the
  /// document line [line].
  ///
  /// Null when the line starts no block, or when the block's row is not on
  /// the screen.
  Offset? foldingTogglePositionForLine(int line) {
    final ranges = _codeController.code.hiddenLineRanges;
    if (line < 0 || line >= ranges.fullLineCount) {
      return null;
    }

    final visible = ranges.cutLineIndexIfVisible(line);
    if (visible == null) {
      return null;
    }

    return foldingTogglePosition(visible);
  }

  /// The top of the visible row [visibleRow], relative to the gutter.
  ///
  /// Null when the row is not on the screen.
  double? rowTop(int visibleRow) {
    final paragraphs = _notifier.value?.paragraphs;
    if (paragraphs == null) {
      return null;
    }

    for (final paragraph in paragraphs) {
      if (paragraph.index == visibleRow) {
        return paragraph.offset.dy;
      }
    }

    return null;
  }

  /// The height of a row of the gutter.
  ///
  /// The row height is the height of a line of the numbers, which is the
  /// height of a line of the code: the numbers and the code share one grid.
  double get rowHeight => _rowHeight;

  /// The height of a row of the gutter.
  ///
  /// The row height is the height of a line of the numbers, which is the
  /// height of a line of the code: the numbers and the code share one grid.
  double get _rowHeight {
    _numberPainter.text = TextSpan(text: '0', style: _numberStyle);
    _numberPainter.layout();
    final height = _numberPainter.height;
    _numberPainter.text = const TextSpan(text: '');
    return height;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final value = _notifier.value;
    if (value == null || value.paragraphs.isEmpty) {
      return;
    }

    final background = _style.background;
    if (background != null) {
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        Paint()..color = background,
      );
    }

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
    );

    final numberColumnWidth = _numberColumnWidth;
    final issueColumnLeft = numberColumnWidth;
    final foldingColumnLeft = issueColumnLeft + _issueColumnWidth;

    final visibleLineNumbers = _codeController
        .code
        .hiddenLineRanges
        .visibleLineNumbers
        .toList();
    final issues = _issuesByLine();
    final foldable = _foldableByLine();

    for (final paragraph in value.paragraphs) {
      final lineIndex = paragraph.index;
      if (lineIndex >= visibleLineNumbers.length) {
        continue;
      }

      final fullLine = visibleLineNumbers[lineIndex];
      final top = offset.dy + paragraph.offset.dy;

      if (_style.showLineNumbers) {
        _numberPainter.text = TextSpan(
          text: '${fullLine + 1}',
          style: _numberStyle,
        );
        _numberPainter.layout();
        final painterWidth = _numberPainter.width;
        final x = switch (_style.textAlign) {
          TextAlign.left || TextAlign.start => offset.dx,
          TextAlign.right ||
          TextAlign.end => offset.dx + numberColumnWidth - painterWidth,
          _ => offset.dx + (numberColumnWidth - painterWidth) / 2,
        };
        _numberPainter.paint(canvas, Offset(x, top));
        final rowHeight = _numberPainter.height;
        _numberPainter.text = const TextSpan(text: '');

        final issue = issues[fullLine];
        if (issue != null) {
          _paintIcon(
            canvas: canvas,
            icon: _style.issueIcon(issue.type),
            color: Colors.red,
            left: offset.dx + issueColumnLeft,
            top: top,
            rowHeight: rowHeight,
            columnWidth: _issueColumnWidth,
          );
        }

        final block = foldable[fullLine];
        if (block != null) {
          _paintChevron(
            canvas: canvas,
            left: offset.dx + foldingColumnLeft,
            top: top,
            rowHeight: rowHeight,
            columnWidth: _foldingColumnWidth,
            isFolded: block.$2,
          );
        }
      } else {
        // The number painter is not laid out when the numbers are hidden —
        // the number column takes no width and is never measured — so the row
        // height is measured here rather than read from the painter.
        final rowHeight = _rowHeight;

        final issue = issues[fullLine];
        if (issue != null) {
          _paintIcon(
            canvas: canvas,
            icon: _style.issueIcon(issue.type),
            color: Colors.red,
            left: offset.dx + issueColumnLeft,
            top: top,
            rowHeight: rowHeight,
            columnWidth: _issueColumnWidth,
          );
        }

        final block = foldable[fullLine];
        if (block != null) {
          _paintChevron(
            canvas: canvas,
            left: offset.dx + foldingColumnLeft,
            top: top,
            rowHeight: rowHeight,
            columnWidth: _foldingColumnWidth,
            isFolded: block.$2,
          );
        }
      }
    }

    canvas.restore();
  }

  void _paintIcon({
    required Canvas canvas,
    required IconData icon,
    required Color color,
    required double left,
    required double top,
    required double rowHeight,
    required double columnWidth,
  }) {
    final size = math.min(
      math.max(_kIssueColumnWidth, _kFoldingColumnWidth),
      rowHeight,
    );
    _iconPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    _iconPainter.layout();
    _iconPainter.paint(
      canvas,
      Offset(
        left + (columnWidth - _iconPainter.width) / 2,
        top + (rowHeight - size) / 2,
      ),
    );
    _iconPainter.text = const TextSpan(text: '');
  }

  void _paintChevron({
    required Canvas canvas,
    required double left,
    required double top,
    required double rowHeight,
    required double columnWidth,
    required bool isFolded,
  }) {
    final size = math.min(
      math.max(_kIssueColumnWidth, _kFoldingColumnWidth),
      rowHeight,
    );
    final color = _style.textStyle?.color;
    if (color == null) {
      return;
    }

    final center = Offset(left + columnWidth / 2, top + rowHeight / 2);
    final radius = size / 3;
    final path = Path();
    if (isFolded) {
      path
        ..moveTo(center.dx - radius, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx - radius, center.dy + radius);
    } else {
      path
        ..moveTo(center.dx - radius, center.dy - radius)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx + radius, center.dy - radius);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// The issues of the document, by the line they are on.
  Map<int, Issue> _issuesByLine() {
    final result = <int, Issue>{};
    for (final issue in _codeController.analysisResult.issues) {
      result.putIfAbsent(issue.line, () => issue);
    }
    return result;
  }

  /// The foldable blocks of the document, by the line they start on.
  ///
  /// The value carries whether the block is folded, so the gutter can draw
  /// the chevron the other way round.
  Map<int, (int, bool)> _foldableByLine() {
    final code = _codeController.code;
    final result = <int, (int, bool)>{};

    for (final block in code.foldableBlocks) {
      result[block.firstLine] = (block.lastLine, false);
    }

    for (final block in code.foldedBlocks) {
      result[block.firstLine] = (block.lastLine, true);
    }

    return result;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      final position = globalToLocal(event.position);
      final line = _lineAt(position);
      if (line != null) {
        _toggleFold(line);
      }
    }
    super.handleEvent(event, entry);
  }

  /// The document line the position is on, or null when it is on none.
  int? _lineAt(Offset position) {
    final value = _notifier.value;
    if (value == null) {
      return null;
    }

    final visibleLineNumbers = _codeController
        .code
        .hiddenLineRanges
        .visibleLineNumbers
        .toList();

    for (final paragraph in value.paragraphs) {
      if (position.dy >= paragraph.top && position.dy < paragraph.bottom) {
        if (paragraph.index >= visibleLineNumbers.length) {
          return null;
        }
        return visibleLineNumbers[paragraph.index];
      }
    }

    return null;
  }

  /// Folds the block at [line], or unfolds it when it is folded already.
  void _toggleFold(int line) {
    final code = _codeController.code;

    for (final block in code.foldedBlocks) {
      if (block.firstLine == line) {
        _codeController.unfoldAt(line);
        return;
      }
    }

    for (final block in code.foldableBlocks) {
      if (block.firstLine == line) {
        _codeController.foldAt(line);
        return;
      }
    }
  }
}
