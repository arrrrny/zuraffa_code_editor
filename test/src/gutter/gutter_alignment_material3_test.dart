import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:highlight/languages/java.dart';

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
  /// Same shape as `gutter_alignment_test.dart`: enough lines that a per-row
  /// difference accumulates into something unmissable.
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

  Future<CodeController> pumpEditor(
    WidgetTester wt, {
    GutterStyle? gutterStyle,
  }) async {
    // Tall enough that the whole gutter fits — the test asserts on real
    // layout, and a RenderFlex overflow would fail it.
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final controller = CodeController(text: buildSource(), language: java);
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: CodeField(controller: controller, gutterStyle: gutterStyle),
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
      return [
        for (var k = 0; k < texts.evaluate().length; k++)
          wt.getRect(texts.at(k)),
      ];
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

  testWidgets('Material 3: unfolded gutter shares the code line grid', (
    wt,
  ) async {
    final controller = await pumpEditor(wt);

    // Guard the reproduction itself: Material 3 must actually hand the editor
    // a `height`, or nothing here distinguishes it from Material 2.
    final editable = wt
        .widgetList<EditableText>(find.byType(EditableText))
        .firstWhere((e) => identical(e.controller, controller));
    expect(
      editable.style.height,
      isNotNull,
      reason: 'M3 titleMedium must supply the line height the fix relies on',
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
      state: 'M3 unfolded',
    );
  });

  testWidgets(
    'Material 3: folded gutter still shares the code line grid',
    (wt) async {
      final controller = await pumpEditor(wt);

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
    },
  );

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
      final controller = await pumpEditor(
        wt,
        gutterStyle: const GutterStyle(
          textStyle: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
      );

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
