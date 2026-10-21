import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:re_editor/re_editor.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import 'package:zuraffa_code_editor/src/code_field/re_editor_controller.dart';

void main() {
  testWidgets('CodeFieldRe renders the controller text', (tester) async {
    final controller = CodeController(text: 'line one\nline two');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeFieldRe(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CodeFieldRe), findsOneWidget);
    controller.dispose();
  });

  testWidgets('an edit in the editor reaches the controller', (tester) async {
    final controller = CodeController(text: 'abc');
    final line = ReEditorCodeController(text: 'abc');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeFieldRe(controller: controller, lineController: line),
        ),
      ),
    );
    await tester.pumpAndSettle();

    line.text = 'abcd';
    await tester.pumpAndSettle();

    expect(controller.code.text, 'abcd');
    controller.dispose();
    line.dispose();
  });

  testWidgets('a fold hides lines in the rendered text', (tester) async {
    final controller = CodeController(
      text: 'class C {\n  void body() {\n    run();\n  }\n}\n',
      language: java,
    );
    final line = ReEditorCodeController(text: controller.code.text);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeFieldRe(controller: controller, lineController: line),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.foldAt(0);
    await tester.pumpAndSettle();

    // The rendered text is the visible one: the folded body is cut out.
    expect(line.text, isNot(contains('run();')));
    expect(controller.code.text, contains('run();'));
    controller.dispose();
    line.dispose();
  });

  testWidgets('the code is highlighted with the controller language', (
    tester,
  ) async {
    final controller = CodeController(text: 'void main() {}', language: java);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeFieldRe(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    final theme = editor.style?.codeTheme;
    expect(theme, isNotNull);
    expect(theme!.languages, hasLength(1));
    expect(theme.languages.values.single.mode, isNotNull);

    controller.dispose();
  });

  testWidgets('the code is styled with the given theme', (tester) async {
    final controller = CodeController(text: 'void main() {}', language: java);
    const keywordStyle = TextStyle(color: Color(0xFF00FF00));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeFieldRe(
            controller: controller,
            theme: CodeThemeData(styles: const {'keyword': keywordStyle}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.style?.codeTheme?.theme['keyword'], keywordStyle);

    controller.dispose();
  });

  testWidgets('code without a language is not highlighted', (tester) async {
    final controller = CodeController(text: 'void main() {}');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeFieldRe(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.style?.codeTheme, isNull);

    controller.dispose();
  });

  testWidgets('a code field renders through re_editor', (tester) async {
    final controller = CodeController(text: 'line one\nline two');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            renderer: CodeFieldRenderer.reEditor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CodeEditor), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    controller.dispose();
  });

  testWidgets('a code field renders through the text field on request', (
    tester,
  ) async {
    final controller = CodeController(text: 'line one\nline two');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            renderer: CodeFieldRenderer.textField,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CodeEditor), findsNothing);

    controller.dispose();
  });

  testWidgets('a code field renders through re_editor by default', (
    tester,
  ) async {
    final controller = CodeController(text: 'line one\nline two');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CodeEditor), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    controller.dispose();
  });

  testWidgets('an edit in a re_editor code field reaches the controller', (
    tester,
  ) async {
    final controller = CodeController(text: 'abc');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            renderer: CodeFieldRenderer.reEditor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller!.text = 'abcd';
    await tester.pumpAndSettle();

    expect(controller.code.text, 'abcd');

    controller.dispose();
  });

  // appended coverage tests
  testWidgets('CodeFieldRe reattaches when its controller is swapped', (tester) async {
    final first = CodeController(text: 'first');
    final second = CodeController(text: 'second');
    final notifier = ValueNotifier<CodeController>(first);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<CodeController>(
            valueListenable: notifier,
            builder: (context, controller, _) =>
                CodeFieldRe(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    notifier.value = second;
    await tester.pumpAndSettle();

    expect(find.byType(CodeFieldRe), findsOneWidget);

    notifier.dispose();
    first.dispose();
    second.dispose();
  });

  testWidgets('CodeFieldRe swaps a provided re_editor controller', (tester) async {
    final controller = CodeController(text: 'abc');
    final firstLine = ReEditorCodeController(text: 'abc');
    final secondLine = ReEditorCodeController(text: 'abc');
    final notifier = ValueNotifier<ReEditorCodeController>(firstLine);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<ReEditorCodeController>(
            valueListenable: notifier,
            builder: (context, line, _) =>
                CodeFieldRe(controller: controller, lineController: line),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    notifier.value = secondLine;
    await tester.pumpAndSettle();

    expect(find.byType(CodeFieldRe), findsOneWidget);

    notifier.dispose();
    controller.dispose();
    firstLine.dispose();
    secondLine.dispose();
  });
}
