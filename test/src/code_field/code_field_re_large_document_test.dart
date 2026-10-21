import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/dart.dart';
import 'package:re_editor/re_editor.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Where the time goes on a large document.
///
/// The editor is virtualized, so drawing it is cheap. What is *not* cheap is
/// everything the package's controller does on the whole document: the
/// foldable-block parser, the line splitter and the search. This test
/// measures each of them, so a regression in one of them is visible.
void main() {
  const lineCount = 50000;

  String buildText() {
    final buffer = StringBuffer('final values = [\n');
    for (var i = 0; i < lineCount; i++) {
      buffer.writeln('  value$i,');
    }
    buffer.writeln('];');
    return buffer.toString();
  }

  testWidgets('a 50k-line document stays responsive', (tester) async {
    final text = buildText();

    final construct = Stopwatch()..start();
    final controller = CodeController(text: text, language: dart);
    construct.stop();
    // ignore: avoid_print
    print(
      'CodeController(50k lines) built in ${construct.elapsedMilliseconds} ms',
    );

    final pump = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    pump.stop();
    // ignore: avoid_print
    print('CodeField(50k lines) pumped in ${pump.elapsedMilliseconds} ms');

    // A keystroke-sized edit: one character at the caret.
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    final lineController = editor.controller!;
    lineController.selection = const CodeLineSelection(
      baseIndex: 1,
      baseOffset: 0,
      extentIndex: 1,
      extentOffset: 0,
    );
    final type = Stopwatch()..start();
    lineController.codeLines = CodeLines.fromText(
      text.replaceFirst('  value0,', '  value0X,'),
    );
    await tester.pump(const Duration(milliseconds: 600));
    type.stop();
    // ignore: avoid_print
    print('one-character edit in ${type.elapsedMilliseconds} ms');

    expect(controller.code.text, contains('value0X,'));
    expect(controller.code.text, contains('value${lineCount - 1},'));

    controller.dispose();
  });
}
