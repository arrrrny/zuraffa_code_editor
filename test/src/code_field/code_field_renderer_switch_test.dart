import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:re_editor/re_editor.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  testWidgets('a right to left field falls back to the text field renderer', (
    tester,
  ) async {
    final controller = CodeController(text: 'void main() {}', language: java);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CodeEditor), findsOneWidget);
    expect(controller.highlightEnabled, isFalse);

    controller.dispose();
  });

  testWidgets('the renderer follows the direction of the field', (
    tester,
  ) async {
    final controller = CodeController(text: 'void main() {}', language: java);

    Widget field(TextDirection direction) {
      return MaterialApp(
        home: Scaffold(
          body: CodeField(controller: controller, textDirection: direction),
        ),
      );
    }

    await tester.pumpWidget(field(TextDirection.ltr));
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(controller.highlightEnabled, isFalse);

    // The re_editor renderer lays the code out left to right only, so a
    // right to left field is drawn with the text field renderer, which needs
    // the package's own highlight.
    await tester.pumpWidget(field(TextDirection.rtl));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.highlightEnabled, isTrue);

    await tester.pumpWidget(field(TextDirection.ltr));
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(controller.highlightEnabled, isFalse);

    controller.dispose();
  });
}
