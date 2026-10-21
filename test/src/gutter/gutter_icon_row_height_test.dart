import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart' as hl_java;

import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Regression: a gutter row must be one code line tall, not one glyph tall.
///
/// The gutter lays its rows out in a `Table`, and a `Table`'s row height is the
/// tallest cell in it. The number's `Text` is exactly one code line tall
/// (`_buildGutter` copies `height` onto the gutter style for that reason), but
/// the two fixed icon columns render their glyph at a hard-coded 16px. Whenever
/// the code's line box is shorter than 16, the icon is the tallest cell in
/// every row it appears in: that row is 16 tall, the row pitch exceeds the code
/// line height by the overshoot, and the gutter separates from the code by that
/// much again on every line below.
///
/// The reported configurations (`height: 1.5` at `fontSize: 16` and `18`) all
/// give a line box of at least 24px, so they never reach the case — which is
/// why the pitch invariant in `gutter_alignment_test.dart` passes on master
/// while the drift is real. Fork issue #107; upstream #312 and #215.
///
/// These tests measure the invariant that catches it: every row's top sits on
/// the code line grid, at any font size.

/// Enough lines for the per-row overshoot to accumulate visibly.
String _buildSource() {
  final lines = <String>['class A {'];
  for (var i = 0; i < 20; i++) {
    lines.add('  int field$i;');
  }
  lines.add('}');
  return '${lines.join('\n')}\n';
}

/// Rendered height of one line of code — not the nominal `fontSize * height`,
/// because Flutter rounds it up to whole pixels.
double _renderedLineHeight(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Xg', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Every gutter number cell's rect, top to bottom.
List<Rect> _gutterRows(WidgetTester wt) {
  final texts = find.descendant(
    of: find.byType(Table),
    matching: find.byType(Text),
  );
  return [
    for (var i = 0; i < texts.evaluate().length; i++)
      if (wt.getRect(texts.at(i)).height > 0) wt.getRect(texts.at(i)),
  ];
}

/// Every gutter icon glyph in the tree, with its rendered size.
List<double> _iconSizes(WidgetTester wt) => [
  for (final e in find.byType(Icon).evaluate()) (e.widget as Icon).size ?? 24.0,
];

TextStyle _editorStyle(WidgetTester wt) {
  return wt.widgetList<EditableText>(find.byType(EditableText)).first.style;
}

Future<CodeController> _pumpEditor(
  WidgetTester wt, {
  required double fontSize,
  double? height,
}) async {
  wt.view.physicalSize = const Size(800, 1200);
  wt.view.devicePixelRatio = 1.0;
  addTearDown(wt.view.reset);

  final controller = CodeController(
    text: _buildSource(),
    language: hl_java.java,
  );
  addTearDown(controller.dispose);

  await wt.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CodeField(
          renderer: CodeFieldRenderer.textField,
          controller: controller,
          textStyle: TextStyle(fontSize: fontSize, height: height),
        ),
      ),
    ),
  );
  await wt.pump();

  return controller;
}

void main() {
  testWidgets('13px line box: gutter rows stay one code line tall', (wt) async {
    // The size the drift is worst at in the common monospace range: 13 < 16,
    // so the icon sets the row height and the pitch is 13.643 against a 13px
    // line box on master.
    await _pumpEditor(wt, fontSize: 13, height: 1.0);

    final lineH = _renderedLineHeight(_editorStyle(wt));
    final rows = _gutterRows(wt);

    expect(rows.length, greaterThan(8));
    for (var i = 0; i < rows.length; i++) {
      expect(
        rows[i].top,
        closeTo(rows.first.top + i * lineH, 0.001),
        reason:
            'gutter row $i is not on the code line grid '
            '(line height $lineH)',
      );
    }

    // The whole point: the last row is as aligned as the first.
    expect(
      rows.last.top,
      closeTo(rows.first.top + (rows.length - 1) * lineH, 0.001),
      reason:
          'the gutter drifts off the code grid by '
          '${rows.last.top - (rows.first.top + (rows.length - 1) * lineH)}px '
          'over ${rows.length} rows',
    );
  });

  testWidgets('sub-16 font sizes: gutter rows stay one code line tall', (
    wt,
  ) async {
    // The whole affected range, because the overshoot is a function of how
    // much shorter than 16 the line box is. 16+ must also stay aligned — it
    // is the boundary at which the clamp becomes a no-op.
    for (final fontSize in [9.0, 10.0, 11.0, 12.0, 14.0, 15.0, 16.0, 18.0]) {
      await _pumpEditor(wt, fontSize: fontSize, height: 1.0);

      final lineH = _renderedLineHeight(_editorStyle(wt));
      final rows = _gutterRows(wt);

      expect(
        lineH,
        closeTo(fontSize, 0.001),
        reason: 'fontSize $fontSize should give a line box of its own height',
      );

      for (var i = 0; i < rows.length; i++) {
        expect(
          rows[i].top,
          closeTo(rows.first.top + i * lineH, 0.001),
          reason:
              'fontSize $fontSize: gutter row $i is off the code grid '
              '(line height $lineH)',
        );
      }
    }
  });

  testWidgets('every visible glyph is clamped to the code line height', (
    wt,
  ) async {
    // The mechanism, rather than its consequence: at a 13px line box the two
    // icon columns render 16px glyphs, and those are what set the row height.
    await _pumpEditor(wt, fontSize: 13, height: 1.0);

    final lineH = _renderedLineHeight(_editorStyle(wt));
    expect(lineH, lessThan(16));

    final sizes = _iconSizes(wt);

    // Folding handles and (when analysis runs) issue icons. Every gutter icon
    // must fit the line box, or it sets its row's height.
    expect(sizes, isNotEmpty);
    for (final size in sizes) {
      expect(
        size,
        lessThanOrEqualTo(lineH),
        reason:
            'a ${size}px glyph sets its row height against a '
            '${lineH}px line box',
      );
    }
  });

  testWidgets('icons stay at 16 above a 16px line box', (wt) async {
    // The clamp must not shrink icons in the normal case: `min(16, lineH)` is
    // 16 wherever the line box is at least 16 tall, so the gutter's geometry
    // and every existing rendering stay byte-identical.
    await _pumpEditor(wt, fontSize: 16, height: 1.5);

    final lineH = _renderedLineHeight(_editorStyle(wt));
    expect(lineH, greaterThanOrEqualTo(16));

    final sizes = _iconSizes(wt);
    expect(sizes, isNotEmpty);
    for (final size in sizes) {
      expect(size, 16.0);
    }
  });
}
