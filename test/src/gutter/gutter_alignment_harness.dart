import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:highlight/languages/java.dart';

/// Shared harness for the gutter/code line-grid regression tests
/// (`gutter_alignment_test.dart` for Material 2 and
/// `gutter_alignment_material3_test.dart` for Material 3).
///
/// Both files assert the same invariant against the same document — the gutter
/// starts on the code text's top edge and every row is exactly one rendered
/// code line tall — and used to carry verbatim copies of these helpers. Kept in
/// one place, parameterised by the theme and the caller's [GutterStyle], so a
/// change to the widget tree or the gutter's layout hides nothing from either
/// case.

/// Two large foldable methods plus a run of plain fields, so there are enough
/// lines for drift to accumulate measurably.
String buildGutterAlignmentSource() {
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

/// Pumps a [CodeField] over [buildGutterAlignmentSource], tall enough that the
/// whole gutter fits — the assertions read real layout, and a RenderFlex
/// overflow would fail them.
///
/// [useMaterial3] selects the theme the code's line box is read from;
/// [textStyle] pins that line box explicitly for the Material 2 case; and
/// [gutterStyle] exercises a caller-supplied gutter style.
Future<CodeController> pumpGutterAlignmentEditor(
  WidgetTester wt, {
  bool useMaterial3 = false,
  TextStyle? textStyle,
  GutterStyle? gutterStyle,
}) async {
  wt.view.physicalSize = const Size(800, 1000);
  wt.view.devicePixelRatio = 1.0;
  addTearDown(wt.view.reset);

  final controller = CodeController(
    text: buildGutterAlignmentSource(),
    language: java,
  );
  addTearDown(controller.dispose);

  await wt.pumpWidget(
    MaterialApp(
      theme: useMaterial3 ? ThemeData(useMaterial3: true) : null,
      home: Scaffold(
        body: CodeField(
          controller: controller,
          textStyle: textStyle,
          gutterStyle: gutterStyle,
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
  final editable = _editableFor(wt, controller);

  final painter = TextPainter(
    text: TextSpan(text: 'Xg', style: editable.style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.height;
}

/// Guards the reproduction itself: the editor's style must actually carry a
/// `height`, or the code and gutter boxes both collapse to the font's own
/// metrics and nothing distinguishes the case under test from the bug. Used by
/// every Material 3 test, including the fault-detecting one, so its detection
/// power cannot silently disappear.
void expectEditorLineHeightSet(WidgetTester wt, CodeController controller) {
  expect(
    _editableFor(wt, controller).style.height,
    isNotNull,
    reason: 'the editor style must supply the line height the fix relies on',
  );
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
      for (var k = 0; k < texts.evaluate().length; k++) wt.getRect(texts.at(k)),
    ];
  }
  throw StateError('No gutter table found for the controller');
}

double textTop(WidgetTester wt, CodeController controller) {
  return wt.getRect(find.byWidget(_editableFor(wt, controller))).top;
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

EditableText _editableFor(WidgetTester wt, CodeController controller) {
  return wt
      .widgetList<EditableText>(find.byType(EditableText))
      .firstWhere((e) => identical(e.controller, controller));
}
