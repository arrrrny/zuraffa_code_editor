import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa_code_editor/src/gutter/error.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

const _message = 'Unused import';
const _popupStyle = TextStyle(
  fontSize: 12,
  color: Colors.amber,
  backgroundColor: Colors.white,
);

const _source = 'class A {\n  void m() {}\n}\n';

class TestAnalyzer extends Mock implements AbstractAnalyzer {
  void setIssues(List<Issue> issues) {
    // ignore: discarded_futures
    when(
      () => analyze(any()),
    ).thenAnswer((_) async => AnalysisResult(issues: issues));
  }
}

class SentinelPopup extends StatelessWidget {
  const SentinelPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('sentinel popup');
  }
}

Widget _sentinel(Issue issue, TextStyle style, BoxDecoration? d) {
  return const SentinelPopup();
}

Widget _sentinel2(Issue issue, TextStyle style, BoxDecoration? d) {
  return const SentinelPopup();
}

void main() {
  setUpAll(() {
    registerFallbackValue(Code.empty);
  });

  Future<CodeController> pumpEditor(WidgetTester wt, GutterStyle style) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final analyzer = TestAnalyzer();
    analyzer.setIssues(const [
      Issue(line: 1, message: _message, type: IssueType.error),
    ]);

    final controller = CodeController(
      text: _source,
      language: java,
      analyzer: analyzer,
    );
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            renderer: CodeFieldRenderer.textField,
            controller: controller,
            gutterStyle: style,
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();
    return controller;
  }

  group('no builder: the built-in widget is unchanged', () {
    testWidgets('renders GutterErrorWidget resolving the default glyph', (
      wt,
    ) async {
      await pumpEditor(wt, const GutterStyle());

      final widget = wt.widget<GutterErrorWidget>(
        find.byType(GutterErrorWidget),
      );
      expect(widget.icon, isA<Icon>());
      final icon = widget.icon as Icon;
      expect(icon.icon, defaultIssueIcon);
      expect(icon.color, Colors.red);
      expect(widget.popupDecoration, isNull);
    });
  });

  group('GutterStyle.errorPopupBuilder', () {
    testWidgets('replaces the widget the gutter mounts', (wt) async {
      await pumpEditor(wt, const GutterStyle(errorPopupBuilder: _sentinel));

      expect(find.byType(SentinelPopup), findsOneWidget);
      expect(find.byType(GutterErrorWidget), findsNothing);
    });

    testWidgets('receives the resolved popup text style and decoration', (
      wt,
    ) async {
      const decoration = BoxDecoration(color: Colors.black);
      Issue? receivedIssue;
      TextStyle? receivedTextStyle;
      BoxDecoration? receivedDecoration;

      await pumpEditor(
        wt,
        GutterStyle(
          errorPopupTextStyle: _popupStyle,
          errorPopupDecoration: decoration,
          errorPopupBuilder: (issue, textStyle, popupDecoration) {
            receivedIssue = issue;
            receivedTextStyle = textStyle;
            receivedDecoration = popupDecoration;
            return const SentinelPopup();
          },
        ),
      );

      expect(receivedIssue?.message, _message);
      expect(receivedIssue?.type, IssueType.error);
      expect(receivedTextStyle, _popupStyle);
      expect(receivedDecoration, decoration);
    });

    testWidgets('is called per issue', (wt) async {
      wt.view.physicalSize = const Size(800, 1000);
      wt.view.devicePixelRatio = 1.0;
      addTearDown(wt.view.reset);

      final analyzer = TestAnalyzer();
      analyzer.setIssues(const [
        Issue(line: 1, message: 'first', type: IssueType.error),
        Issue(line: 2, message: 'second', type: IssueType.warning),
      ]);

      final controller = CodeController(
        text: _source,
        language: java,
        analyzer: analyzer,
      );
      addTearDown(controller.dispose);

      final messages = <String>[];
      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              renderer: CodeFieldRenderer.textField,
              controller: controller,
              gutterStyle: GutterStyle(
                errorPopupBuilder: (issue, textStyle, decoration) {
                  messages.add(issue.message);
                  return const SentinelPopup();
                },
              ),
            ),
          ),
        ),
      );
      await wt.pumpAndSettle();

      expect(messages, ['first', 'second']);
      expect(find.byType(SentinelPopup), findsNWidgets(2));
    });

    testWidgets('the null text style still throws', (wt) async {
      final analyzer = TestAnalyzer();
      analyzer.setIssues(const [
        Issue(line: 1, message: _message, type: IssueType.error),
      ]);

      final controller = CodeController(
        text: _source,
        language: java,
        analyzer: analyzer,
      );
      addTearDown(controller.dispose);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GutterWidget(
                codeController: controller,
                style: const GutterStyle(errorPopupBuilder: _sentinel),
                scrollController: null,
              ),
            ),
          ),
        ),
      );

      expect(
        wt.takeException(),
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Error popup style should never be null'),
        ),
      );
    });
  });

  group('copyWith', () {
    test('carries the builder', () {
      final style = GutterStyle(errorPopupBuilder: _sentinel);

      expect(style.copyWith().errorPopupBuilder, _sentinel);
      expect(
        style.copyWith(errorPopupBuilder: _sentinel).errorPopupBuilder,
        _sentinel,
      );
      expect(
        style.copyWith(errorPopupBuilder: _sentinel2).errorPopupBuilder,
        _sentinel2,
      );
      expect(
        style.copyWith(errorPopupBuilder: null).errorPopupBuilder,
        _sentinel,
      );
    });
  });
}
