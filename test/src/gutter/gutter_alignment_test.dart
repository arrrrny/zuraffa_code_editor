import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:highlight/languages/java.dart';

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
  /// Two large foldable methods plus a run of plain fields, so there are
  /// enough lines for drift to accumulate measurably.
  String buildSource() {
    final lines = <String>['class A {', '  void m() {'];
    for (var i = 0; i < 10; i++) {
      lines.add('    int a$i;');
    }
    lines.add('  }');
    lines.add('  void n() {');
    for (var i = 0; i < 10; i++) {
      lines.add('    int b$i;');
    }
    lines.add('  }');
    for (var i = 0; i < 10; i++) {
      lines.add('  int t$i;');
    }
    lines.add('}');
    return '${lines.join('\n')}\n';
  }

  Future<CodeController> pumpEditor(WidgetTester wt) async {
    // Tall enough that the whole gutter fits — the test asserts on real
    // layout, and a RenderFlex overflow would fail it.
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final controller = CodeController(text: buildSource(), language: java);
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            textStyle: const TextStyle(
              fontSize: 13,
              height: 1.6,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ),
      ),
    );
    await wt.pump();
    return controller;
  }

  /// The rendered height of one line of code — not the nominal
  /// `fontSize * height`, because Flutter rounds it up to whole pixels.
  double renderedLineHeight(WidgetTester wt, CodeController controller) {
    final editable = wt
        .widgetList<EditableText>(find.byType(EditableText))
        .firstWhere((e) => identical(e.controller, controller));

    final painter = TextPainter(
      text: TextSpan(text: 'Xg', style: editable.style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.height;
  }

  /// One [Rect] per line-number cell, top to bottom.
  List<Rect> gutterRows(WidgetTester wt, CodeController controller) {
    final field = wt
        .widgetList<CodeField>(find.byType(CodeField))
        .firstWhere((w) => identical(w.controller, controller));
    final fieldBox = wt.getRect(find.byWidget(field));

    final tables = find.byType(Table);
    for (var i = 0; i < tables.evaluate().length; i++) {
      final table = tables.at(i);
      final box = wt.getRect(table);
      // Only this field's gutter, not any other table in the tree.
      if (box.left < fieldBox.left - 4 || box.left > fieldBox.left + 120) {
        continue;
      }
      if (box.height < 50) continue;

      final texts = find.descendant(of: table, matching: find.byType(Text));
      final rows = [
        for (var k = 0; k < texts.evaluate().length; k++)
          wt.getRect(texts.at(k)),
      ];
      return rows;
    }
    throw StateError('No gutter table found for the controller');
  }

  double textTop(WidgetTester wt, CodeController controller) {
    final editable = wt
        .widgetList<EditableText>(find.byType(EditableText))
        .firstWhere((e) => identical(e.controller, controller));
    return wt.getRect(find.byWidget(editable)).top;
  }

  void expectOnGrid(
    List<Rect> rows, {
    required double top,
    required double lineHeight,
    required String state,
  }) {
    expect(
      rows.first.top,
      top,
      reason: '$state: gutter must start on the code text grid',
    );

    final pitch = (rows.last.top - rows.first.top) / (rows.length - 1);
    expect(
      pitch,
      closeTo(lineHeight, 0.001),
      reason:
          '$state: gutter row pitch must equal the rendered code line '
          'height ($lineHeight), was $pitch over ${rows.length} rows',
    );

    for (var i = 0; i < rows.length; i++) {
      expect(
        rows[i].top,
        closeTo(top + i * lineHeight, 0.001),
        reason: '$state: gutter row $i has drifted off the code line grid',
      );
    }
  }

  testWidgets('Unfolded gutter shares the code line grid', (wt) async {
    final controller = await pumpEditor(wt);

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
    final controller = await pumpEditor(wt);

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
