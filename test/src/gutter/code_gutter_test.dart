import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:re_editor/re_editor.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// A paragraph that draws nothing.
///
/// The gutter reads the paragraphs the editor has laid out — their index and
/// their offset — and paints a row of the gutter beside each of them. A
/// paragraph that draws nothing is enough for a test that is about the gutter,
/// and it keeps the test independent of the editor's own layout.
class _FakeParagraph implements IParagraph {
  const _FakeParagraph();

  @override
  double get width => 40;

  @override
  double get height => 18;

  @override
  double get preferredLineHeight => 18;

  @override
  bool get trucated => false;

  @override
  int get length => 3;

  @override
  int get lineCount => 1;

  @override
  void draw(Canvas canvas, Offset offset) {}

  @override
  TextPosition getPosition(Offset offset) => const TextPosition(offset: 0);

  @override
  TextRange getWord(Offset offset) => const TextRange(start: 0, end: 0);

  @override
  InlineSpan? getSpanForPosition(TextPosition position) => null;

  @override
  TextRange getRangeForSpan(InlineSpan span) =>
      const TextRange(start: 0, end: 0);

  @override
  TextRange getLineBoundary(TextPosition position) =>
      const TextRange(start: 0, end: 0);

  @override
  Offset? getOffset(TextPosition position) => Offset.zero;

  @override
  List<Rect> getRangeRects(TextRange range) => const [];
}

/// An analyzer that always reports the same issues.
///
/// The gutter paints the issues of the analysis result, so a test needs a
/// result it controls: the default analyzer reports the invalid blocks of the
/// document, and a well formed document has none.
class _FixedAnalyzer extends AbstractAnalyzer {
  const _FixedAnalyzer(this.issues);

  final List<Issue> issues;

  @override
  Future<AnalysisResult> analyze(Code code) async {
    return AnalysisResult(issues: issues);
  }
}

/// The pixels of a painted region.
class _Pixels {
  _Pixels(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final Uint8List bytes;

  /// The colour of the pixel at [x], [y], as `0xAARRGGBB`.
  int argbAt(int x, int y) {
    final i = (y * width + x) * 4;
    return (bytes[i + 3] << 24) |
        (bytes[i + 2] << 16) |
        (bytes[i + 1] << 8) |
        bytes[i];
  }

  /// Whether the pixel at [x], [y] holds anything at all.
  bool isInk(int x, int y) => argbAt(x, y) != 0;

  /// The leftmost column of the region [from]..[to] that holds anything.
  int? firstInkColumn(double from, double to) {
    for (var x = from.floor(); x < to.ceil(); x++) {
      for (var y = 0; y < height; y++) {
        if (isInk(x, y)) {
          return x;
        }
      }
    }
    return null;
  }

  /// The rightmost column of the region [from]..[to] that holds anything.
  int? lastInkColumn(double from, double to) {
    for (var x = to.ceil() - 1; x >= from.floor(); x--) {
      for (var y = 0; y < height; y++) {
        if (isInk(x, y)) {
          return x;
        }
      }
    }
    return null;
  }

  /// Whether the region [from]..[to] holds anything at all.
  bool hasInk(double from, double to) => firstInkColumn(from, to) != null;

  /// The number of columns of the row [y] that hold anything, within
  /// [from]..[to].
  int inkWidthAt(int y, double from, double to) {
    var count = 0;
    for (var x = from.floor(); x < to.ceil(); x++) {
      if (isInk(x, y)) {
        count++;
      }
    }
    return count;
  }

  /// The number of runs of ink in the row [y], within [from]..[to].
  ///
  /// A run is a stretch of columns that all hold something, with a gap
  /// between it and the next one.
  int inkRunsAt(int y, double from, double to) {
    var runs = 0;
    var inRun = false;
    for (var x = from.floor(); x < to.ceil(); x++) {
      final ink = isInk(x, y);
      if (ink && !inRun) {
        runs++;
      }
      inRun = ink;
    }
    return runs;
  }

  /// The number of runs of ink over the rows [fromRow]..[toRow], within
  /// [from]..[to].
  int inkRunsIn(int fromRow, int toRow, double from, double to) {
    var runs = 0;
    for (var y = fromRow; y < toRow; y++) {
      runs += inkRunsAt(y, from, to);
    }
    return runs;
  }
}

/// The width of the gutter's issue column.
const double _issueColumnWidth = 16;

/// The width of the gutter's folding column.
const double _foldingColumnWidth = 16;

/// The margin between the numbers and the code.
const double _margin = 10;

const ValueKey<Object> _boundaryKey = ValueKey('gutter');

void main() {
  const javaCode = 'class C {\n  void body() {\n    run();\n  }\n}\n';

  /// A notifier that publishes [lines] laid out paragraphs.
  CodeIndicatorValueNotifier notifierWith(int lines) {
    return CodeIndicatorValueNotifier(
      CodeIndicatorValue(
        paragraphs: [
          for (var i = 0; i < lines; i++)
            CodeLineRenderParagraph(
              index: i,
              paragraph: const _FakeParagraph(),
              offset: Offset(0, i * 18),
              chunkParent: false,
              chunkLongText: false,
            ),
        ],
      ),
    );
  }

  /// Pumps a gutter of its own, so a test can drive the render object
  /// directly.
  Future<void> pumpGutter(
    WidgetTester tester, {
    required CodeController controller,
    required CodeIndicatorValueNotifier notifier,
    GutterStyle style = const GutterStyle(),
    TextStyle codeTextStyle = const TextStyle(fontSize: 13, height: 1.4),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 200,
              child: RepaintBoundary(
                key: _boundaryKey,
                child: CodeGutter(
                  codeController: controller,
                  notifier: notifier,
                  style: style,
                  codeTextStyle: codeTextStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The pixels the gutter painted.
  ///
  /// The capture runs outside the test's fake clock: the image is rasterised
  /// on the real event loop, which the test body cannot wait for.
  Future<_Pixels> paintedPixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final width = image.width;
      final height = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return _Pixels(width, height, data!.buffer.asUint8List());
    });
    return pixels!;
  }

  /// The width of the gutter's number column.
  double numberColumnWidth(CodeGutterRenderObject gutter) =>
      gutter.size.width - _issueColumnWidth - _foldingColumnWidth - _margin;

  /// The region of the issue column, past the ink of the numbers.
  ///
  /// The numbers end at the right edge of their own column, which touches
  /// the issue column, so the region starts a couple of pixels into it.
  (double, double) issueRegion(CodeGutterRenderObject gutter) {
    final column = numberColumnWidth(gutter);
    return (column + 3, column + _issueColumnWidth - 1);
  }

  group('the gutter in a code field', () {
    testWidgets('the gutter numbers the document lines', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeFieldRe(
              controller: controller,
              gutterStyle: const GutterStyle(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.numberForVisibleRow(0), '1');
      expect(gutter.numberForVisibleRow(1), '2');
      expect(gutter.numberForVisibleRow(4), '5');
      expect(gutter.numberForVisibleRow(5), '6');
      expect(gutter.numberForVisibleRow(6), isNull);

      controller.dispose();
    });

    testWidgets('the gutter numbers the document lines a fold left out', (
      tester,
    ) async {
      final controller = CodeController(text: javaCode, language: java);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeFieldRe(
              controller: controller,
              gutterStyle: const GutterStyle(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.foldAt(0);
      await tester.pumpAndSettle();

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      // The fold glues the closing brace onto the row of the opener, so the
      // second row the editor renders is the last line of the document.
      expect(gutter.numberForVisibleRow(0), '1');
      expect(gutter.numberForVisibleRow(1), '6');
      expect(gutter.numberForVisibleRow(2), isNull);

      controller.dispose();
    });

    testWidgets('a tap on the folding column folds a block', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeFieldRe(
              controller: controller,
              gutterStyle: const GutterStyle(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final topLeft = tester.getTopLeft(find.byType(CodeGutter));
      final toggle = gutter.foldingTogglePosition(0);
      expect(toggle, isNotNull);

      await tester.tapAt(topLeft + toggle!);
      await tester.pumpAndSettle();

      expect(controller.code.foldedBlocks, isNotEmpty);

      controller.dispose();
    });
  });

  group('the gutter of its own', () {
    testWidgets('it lays out the columns of the style', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.size.width, 80);
      expect(gutter.size.height, 200);

      controller.dispose();
    });

    testWidgets('it numbers the rows of the paragraphs', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.numberForVisibleRow(0), '1');
      expect(gutter.numberForVisibleRow(4), '5');
      expect(gutter.numberForVisibleRow(5), '6');
      expect(gutter.numberForVisibleRow(6), isNull);

      controller.dispose();
    });

    testWidgets('it measures the row of a paragraph', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.rowTop(0), 0);
      expect(gutter.rowTop(1), 18);
      expect(gutter.rowTop(9), isNull);
      expect(gutter.rowHeight, greaterThan(10));

      controller.dispose();
    });

    testWidgets('it places the folding handle of a row', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final toggle = gutter.foldingTogglePosition(0);
      expect(toggle, isNotNull);
      expect(toggle!.dx, 80 - _margin - _foldingColumnWidth / 2);
      expect(gutter.foldingTogglePosition(9), isNull);

      controller.dispose();
    });

    testWidgets('it places the folding handle of a document line', (
      tester,
    ) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.foldingTogglePositionForLine(0), isNotNull);
      // A line that is not on the screen has no handle.
      expect(gutter.foldingTogglePositionForLine(99), isNull);

      controller.dispose();
    });

    testWidgets('it paints its background', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(background: Color(0xFF00FF00)),
      );

      final pixels = await paintedPixels(tester);
      expect(pixels.argbAt(2, 199), 0xFF00FF00);

      controller.dispose();
    });

    testWidgets('it centres the numbers', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(textAlign: TextAlign.center),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final column = numberColumnWidth(gutter);
      final pixels = await paintedPixels(tester);
      final first = pixels.firstInkColumn(0, column);
      final last = pixels.lastInkColumn(0, column);
      expect(first, isNotNull);
      expect(last, isNotNull);
      // The number sits in the middle of the column, not against its edge.
      expect(first! - 0, closeTo(column - last! - 1, 2));

      controller.dispose();
    });

    testWidgets('it paints the numbers against the right of the column', (
      tester,
    ) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final column = numberColumnWidth(gutter);
      final pixels = await paintedPixels(tester);
      final last = pixels.lastInkColumn(0, column);
      expect(last, isNotNull);
      // The number ends at the right edge of the column.
      expect(column - last! - 1, lessThan(2));

      controller.dispose();
    });

    testWidgets('it paints the issue of a line', (tester) async {
      final controller = CodeController(
        text: javaCode,
        language: java,
        analyzer: const _FixedAnalyzer([
          Issue(line: 0, message: 'boom', type: IssueType.error),
        ]),
      );
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final region = issueRegion(gutter);
      final pixels = await paintedPixels(tester);
      expect(pixels.hasInk(region.$1, region.$2), isTrue);

      controller.dispose();
    });

    testWidgets('it paints no issue where the document has none', (
      tester,
    ) async {
      final controller = CodeController(text: 'one\ntwo\n');
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final region = issueRegion(gutter);
      final pixels = await paintedPixels(tester);
      expect(pixels.hasInk(region.$1, region.$2), isFalse);

      controller.dispose();
    });

    testWidgets('it paints the issue and the handle without the numbers', (
      tester,
    ) async {
      final controller = CodeController(
        text: javaCode,
        language: java,
        analyzer: const _FixedAnalyzer([
          Issue(line: 0, message: 'boom', type: IssueType.error),
        ]),
      );
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(
          showLineNumbers: false,
          textStyle: TextStyle(color: Color(0xFF000000)),
        ),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      // Without the numbers the number column takes no width.
      expect(numberColumnWidth(gutter), 0);
      final region = issueRegion(gutter);
      final pixels = await paintedPixels(tester);
      expect(pixels.hasInk(region.$1, region.$2), isTrue);
      expect(
        pixels.hasInk(
          _issueColumnWidth,
          _issueColumnWidth + _foldingColumnWidth,
        ),
        isTrue,
      );

      controller.dispose();
    });

    testWidgets('it paints the handle of a foldable block', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(
          textStyle: TextStyle(color: Color(0xFF000000)),
        ),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final column = numberColumnWidth(gutter) + _issueColumnWidth;
      final pixels = await paintedPixels(tester);
      expect(pixels.hasInk(column, column + _foldingColumnWidth), isTrue);

      controller.dispose();
    });

    testWidgets('it paints the folded handle of a folded block', (
      tester,
    ) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(
          textStyle: TextStyle(color: Color(0xFF000000)),
        ),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final column = numberColumnWidth(gutter) + _issueColumnWidth;
      // The band the handle of the first row is drawn in.
      final band = gutter.rowHeight.ceil();

      final unfolded = await paintedPixels(tester);
      final unfoldedRuns = unfolded.inkRunsIn(
        0,
        band,
        column,
        column + _foldingColumnWidth,
      );

      controller.foldAt(0);
      await tester.pumpAndSettle();

      final folded = await paintedPixels(tester);
      final foldedRuns = folded.inkRunsIn(
        0,
        band,
        column,
        column + _foldingColumnWidth,
      );

      // The handle that points down is drawn with two strokes, and the one
      // that points to the side with a single one, so the folded handle
      // covers fewer runs of ink.
      expect(unfoldedRuns, greaterThan(foldedRuns));

      controller.dispose();
    });

    testWidgets('it paints no handle where the document has none', (
      tester,
    ) async {
      final controller = CodeController(text: 'one\ntwo\n');
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(
          textStyle: TextStyle(color: Color(0xFF000000)),
        ),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final column = numberColumnWidth(gutter) + _issueColumnWidth;
      final pixels = await paintedPixels(tester);
      expect(pixels.hasInk(column, column + _foldingColumnWidth), isFalse);

      controller.dispose();
    });

    testWidgets('a tap folds a block and a second tap unfolds it', (
      tester,
    ) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      final topLeft = tester.getTopLeft(find.byType(CodeGutter));
      await tester.tapAt(topLeft + const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(controller.code.foldedBlocks, isNotEmpty);

      await tester.tapAt(topLeft + const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(controller.code.foldedBlocks, isEmpty);

      controller.dispose();
    });

    testWidgets('it follows the controller it is given', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      final other = CodeController(text: 'one\ntwo\n');
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(
          textStyle: TextStyle(color: Color(0xFF000000)),
        ),
      );

      final gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final column = numberColumnWidth(gutter) + _issueColumnWidth;
      var pixels = await paintedPixels(tester);
      expect(pixels.hasInk(column, column + _foldingColumnWidth), isTrue);

      // The document of the other controller has no block to fold.
      await pumpGutter(
        tester,
        controller: other,
        notifier: notifierWith(5),
        style: const GutterStyle(
          textStyle: TextStyle(color: Color(0xFF000000)),
        ),
      );
      pixels = await paintedPixels(tester);
      expect(pixels.hasInk(column, column + _foldingColumnWidth), isFalse);

      controller.dispose();
      other.dispose();
    });

    testWidgets('it follows the notifier it is given', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      var gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.foldingTogglePosition(0), isNotNull);

      await pumpGutter(
        tester,
        controller: controller,
        notifier: CodeIndicatorValueNotifier(null),
      );
      gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.foldingTogglePosition(0), isNull);
      expect(gutter.rowTop(0), isNull);

      controller.dispose();
    });

    testWidgets('it follows the style it is given', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      var gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.size.width, 80);

      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        style: const GutterStyle(width: 120),
      );
      gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.size.width, 120);

      controller.dispose();
    });

    testWidgets('it follows the code style it is given', (tester) async {
      final controller = CodeController(text: javaCode, language: java);
      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
      );

      var gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      final small = gutter.rowHeight;

      await pumpGutter(
        tester,
        controller: controller,
        notifier: notifierWith(5),
        codeTextStyle: const TextStyle(fontSize: 30, height: 1.4),
      );
      gutter = tester.renderObject<CodeGutterRenderObject>(
        find.byType(CodeGutter),
      );
      expect(gutter.rowHeight, greaterThan(small));

      controller.dispose();
    });
  });
}
