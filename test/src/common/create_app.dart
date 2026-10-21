import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/java.dart';

FocusNode focusNode = FocusNode();

/// Passed controller will be disposed with the widget.
MaterialApp createApp(
  CodeController controller,
  FocusNode focusNode, {
  CodeFieldRenderer renderer = CodeFieldRenderer.textField,
}) {
  return MaterialApp(
    home: TestApp(
      controller: controller,
      focusNode: focusNode,
      renderer: renderer,
    ),
  );
}

Future<CodeController> pumpController(
  WidgetTester wt,
  String text, {
  Mode? language,
  CodeFieldRenderer renderer = CodeFieldRenderer.textField,
}) async {
  final controller = createController(
    text,
    language: language,
    highlightEnabled: renderer == CodeFieldRenderer.textField,
  );

  focusNode = FocusNode();
  await wt.pumpWidget(createApp(controller, focusNode, renderer: renderer));
  focusNode.requestFocus();

  return controller;
}

CodeController createController(
  String text, {
  Mode? language,
  Set<String> visibleSectionNames = const {},
  bool highlightEnabled = true,
}) {
  return CodeController(
    text: text,
    language: language ?? java,
    namedSectionParser: const BracketsStartEndNamedSectionParser(),
    visibleSectionNames: visibleSectionNames,
    highlightEnabled: highlightEnabled,
  );
}

class TestApp extends StatefulWidget {
  final CodeController controller;
  final FocusNode focusNode;

  /// The renderer the code is drawn with.
  ///
  /// The text field renderer by default: the tests that use this harness
  /// drive the caret with the text field's own keyboard semantics — the home
  /// and end keys, the arrow keys — and the re_editor renderer binds those
  /// keys differently. The re_editor renderer has its own tests, which drive
  /// the editor's controller directly.
  final CodeFieldRenderer renderer;

  const TestApp({
    super.key,
    required this.controller,
    required this.focusNode,
    this.renderer = CodeFieldRenderer.textField,
  });

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  late final controller = widget.controller;
  late final focusNode = widget.focusNode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CodeField(
        controller: controller,
        focusNode: focusNode,
        renderer: widget.renderer,
      ),
    );
  }

  /// We need to dispose controller because it has debounce timer inside.
  /// If we don't dispose it,
  /// all tests that uses widget tester will start to fail.
  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }
}
