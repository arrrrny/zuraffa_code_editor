import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:re_editor/re_editor.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Folding parity of the re_editor renderer.
///
/// The re editor never learns about folds: the bridge renders the controller's
/// *visible* text, so the fold model stays the package's own. These tests pin
/// that the visible text is what the editor shows — the closing line included
/// — and that folding and unfolding never loses a line.
void main() {
  const config =
      'final config = ScraperConfig(\n'
      '  clientType: HttpClientType.crawler,\n'
      '  parsers: [\n'
      '    ParserConfig(\n'
      '      kind: ParserType.jsonLd,\n'
      '    ),\n'
      '  ],\n'
      ');\n';

  Future<CodeController> pumpField(WidgetTester tester) async {
    final controller = CodeController(text: config, language: java);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// The text the editor actually shows.
  String renderedText(WidgetTester tester) =>
      tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text;

  testWidgets('the editor shows the visible text', (tester) async {
    final controller = await pumpField(tester);

    expect(renderedText(tester), config);

    controller.dispose();
  });

  testWidgets('a folded block keeps its closing line on screen', (
    tester,
  ) async {
    final controller = await pumpField(tester);

    controller.foldAt(2); // `  parsers: [`

    expect(renderedText(tester), '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ],
);
''');

    controller.dispose();
  });

  testWidgets('folding and unfolding is lossless', (tester) async {
    final controller = await pumpField(tester);

    controller.foldAt(2);
    controller.foldAt(3);
    expect(controller.code.text, config, reason: 'the full text survives');

    controller.unfoldAt(2);
    controller.unfoldAt(3);

    expect(renderedText(tester), config);
    expect(controller.code.text, config);
    expect(controller.code.foldedBlocks, isEmpty);

    controller.dispose();
  });

  testWidgets('an edit made while folded keeps the hidden lines', (
    tester,
  ) async {
    final controller = await pumpField(tester);

    controller.foldAt(2);

    // The editor reports the visible text; the controller's diff has to map
    // it back onto the full text so the folded body survives the edit.
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller!.text = '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ],
);
''';
    await tester.pumpAndSettle();

    expect(controller.code.text, contains('kind: ParserType.jsonLd,'));
    expect(controller.code.text, contains('ParserConfig('));

    controller.dispose();
  });
}
