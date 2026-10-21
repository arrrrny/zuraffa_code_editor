import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  const lineCount = 20000;

  testWidgets('benchmark: text field renderer', (tester) async {
    final text = List.generate(lineCount, (i) => 'final x$i = $i;').join('\n');
    final controller = CodeController(text: text);

    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller, expands: true)),
      ),
    );
    await tester.pumpAndSettle();
    stopwatch.stop();

    // ignore: avoid_print
    print('textField renderer: ${stopwatch.elapsedMilliseconds}ms');
    controller.dispose();
  });

  testWidgets('benchmark: re editor renderer', (tester) async {
    final text = List.generate(lineCount, (i) => 'final x$i = $i;').join('\n');
    final controller = CodeController(text: text);

    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            renderer: CodeFieldRenderer.reEditor,
            expands: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    stopwatch.stop();

    // ignore: avoid_print
    print('reEditor renderer: ${stopwatch.elapsedMilliseconds}ms');
    controller.dispose();
  });
}
