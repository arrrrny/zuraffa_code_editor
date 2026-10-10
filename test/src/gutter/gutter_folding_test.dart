import 'package:zuraffa_code_editor/src/gutter/error.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/src/gutter/fold_toggle.dart';
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class TestAnalyzer extends Mock implements AbstractAnalyzer {
  void setIssues(List<Issue> issues) {
    // ignore: discarded_futures
    when(
      () => analyze(any()),
    ).thenAnswer((_) async => AnalysisResult(issues: issues));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Code.empty);
  });

  const source =
      'class A {\n'
      '  void m() {\n'
      '    int a;\n'
      '  }\n'
      '  void n() {\n'
      '    int b;\n'
      '  }\n'
      '}\n';

  testWidgets('an issue on a hidden line is skipped by the gutter', (wt) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final analyzer = TestAnalyzer();
    analyzer.setIssues(const [
      Issue(line: 3, message: 'hidden', type: IssueType.warning),
    ]);

    final controller = CodeController(
      text: source,
      language: java,
      analyzer: analyzer,
    );
    addTearDown(controller.dispose);

    // Fold the first method away, hiding lines 1-3 (0-based).
    controller.foldAt(1);
    await wt.pump();

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            gutterStyle: GutterStyle(
              showErrors: true,
              showFoldingHandles: true,
            ),
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();

    // No error widget is created for a line the gutter has no row for.
    expect(find.byType(GutterWidget), findsOneWidget);
    // The hidden line's issue must not surface an error widget.
    expect(find.byType(GutterErrorWidget), findsNothing);
    expect(
      controller.code.hiddenLineRanges.visibleLineNumbers.length,
      lessThan(controller.code.lines.length),
    );
  });

  testWidgets('a visible issue gets an error widget', (wt) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final analyzer = TestAnalyzer();
    analyzer.setIssues(const [
      Issue(line: 0, message: 'visible', type: IssueType.warning),
    ]);

    final controller = CodeController(
      text: source,
      language: java,
      analyzer: analyzer,
    );
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            gutterStyle: GutterStyle(
              showErrors: true,
              showFoldingHandles: true,
              errorPopupTextStyle: TextStyle(),
            ),
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();

    expect(find.byType(GutterErrorWidget), findsOneWidget);
  });

  testWidgets('an absent error popup style raises while building the gutter', (
    wt,
  ) async {
    // `CodeField` always injects a fallback `errorPopupTextStyle`, so this
    // branch is only reachable by driving `GutterWidget` directly.
    final analyzer = TestAnalyzer();
    analyzer.setIssues(const [
      Issue(line: 0, message: 'visible', type: IssueType.warning),
    ]);

    final controller = CodeController(
      text: source,
      language: java,
      analyzer: analyzer,
    );
    addTearDown(controller.dispose);
    await controller.analyzeCode();

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GutterWidget(
            codeController: controller,
            style: const GutterStyle(showErrors: true),
            scrollController: null,
          ),
        ),
      ),
    );

    expect(wt.takeException(), isA<Exception>());
  });

  testWidgets('fold toggles render for every folded block', (wt) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final controller = CodeController(text: source, language: java);
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            gutterStyle: GutterStyle(
              showLineNumbers: false,
              showErrors: false,
              showFoldingHandles: true,
            ),
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();

    expect(find.byType(FoldToggle), findsAtLeastNWidgets(1));

    controller.foldAt(1);
    await wt.pumpAndSettle();

    // Still at least one toggle, now pointing at unfold.
    expect(find.byType(FoldToggle), findsAtLeastNWidgets(1));

    controller.unfoldAt(1);
    await wt.pumpAndSettle();

    expect(find.byType(FoldToggle), findsAtLeastNWidgets(1));

    // The toggle itself folds and unfolds.
    await wt.tap(find.byType(FoldToggle).first);
    await wt.pumpAndSettle();
    expect(controller.code.foldedBlocks, isNotEmpty);

    await wt.tap(find.byType(FoldToggle).first);
    await wt.pumpAndSettle();
  });
}
