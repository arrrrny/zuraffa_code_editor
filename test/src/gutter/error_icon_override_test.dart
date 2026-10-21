import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa_code_editor/src/gutter/error.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// The size and colour the gutter's icon has always been rendered at.
///
/// The issue column is 16 wide, so the glyph is part of the row geometry and is
/// deliberately not part of the style surface.
const _iconColor = Colors.red;
const _iconSize = 16.0;

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

  group('GutterStyle.issueIcon', () {
    test('a bare style resolves every IssueType to the default', () {
      const style = GutterStyle();

      for (final type in IssueType.values) {
        expect(
          style.issueIcon(type),
          defaultIssueIcon,
          reason: '$type must fall back when the style sets nothing',
        );
      }
    });

    test('the default is the glyph errorIcon has always rendered', () {
      // If this moves, every user who never asked for a custom icon sees a
      // different one.
      expect(defaultIssueIcon, Icons.cancel);
      expect(
        errorIcon.icon,
        defaultIssueIcon,
        reason: 'errorIcon must be built from defaultIssueIcon, not beside it',
      );
    });

    test('each type reads its own field', () {
      const style = GutterStyle(
        errorIcon: Icons.bug_report,
        warningIcon: Icons.warning_amber,
        infoIcon: Icons.info_outline,
      );

      expect(style.issueIcon(IssueType.error), Icons.bug_report);
      expect(style.issueIcon(IssueType.warning), Icons.warning_amber);
      expect(style.issueIcon(IssueType.info), Icons.info_outline);
    });

    test('the fields are independent, not a fallback chain', () {
      const style = GutterStyle(infoIcon: Icons.info_outline);

      expect(style.issueIcon(IssueType.info), Icons.info_outline);
      expect(style.issueIcon(IssueType.error), defaultIssueIcon);
      expect(style.issueIcon(IssueType.warning), defaultIssueIcon);
    });

    test('never returns null, whatever the style', () {
      const style = GutterStyle(
        errorIcon: Icons.bug_report,
        warningIcon: null,
        infoIcon: null,
      );

      // Pin the concrete glyph per type: the non-nullable return type alone is
      // a compile-time property, so only an exact expectation can fail.
      expect(style.issueIcon(IssueType.error), Icons.bug_report);
      expect(style.issueIcon(IssueType.warning), defaultIssueIcon);
      expect(style.issueIcon(IssueType.info), defaultIssueIcon);
    });
  });

  group('GutterStyle.copyWith', () {
    test('carries the icon fields it is not given', () {
      const style = GutterStyle(
        errorIcon: Icons.bug_report,
        warningIcon: Icons.warning_amber,
        infoIcon: Icons.info_outline,
      );

      final copied = style.copyWith(textStyle: const TextStyle());

      expect(copied.errorIcon, Icons.bug_report);
      expect(copied.warningIcon, Icons.warning_amber);
      expect(copied.infoIcon, Icons.info_outline);
    });

    test('replaces only the field it is given', () {
      const style = GutterStyle(
        errorIcon: Icons.bug_report,
        warningIcon: Icons.warning_amber,
        infoIcon: Icons.info_outline,
      );

      final copied = style.copyWith(infoIcon: Icons.lightbulb_outline);

      expect(copied.errorIcon, Icons.bug_report);
      expect(copied.warningIcon, Icons.warning_amber);
      expect(copied.infoIcon, Icons.lightbulb_outline);
    });
  });

  group('GutterErrorWidget icon', () {
    const issue = Issue(
      line: 1,
      message: 'Unused import',
      type: IssueType.warning,
    );
    const popupStyle = TextStyle(fontSize: 12, color: Colors.black);

    testWidgets('renders the default glyph when given no icon', (wt) async {
      await wt.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: GutterErrorWidget(issue, popupStyle)),
          ),
        ),
      );

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      final icon = wt.widget<Icon>(find.byIcon(Icons.cancel));
      expect(icon.color, _iconColor);
      expect(icon.size, _iconSize);
    });

    testWidgets('renders the icon it is given instead', (wt) async {
      await wt.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GutterErrorWidget(
                issue,
                popupStyle,
                icon: Icon(Icons.bug_report, color: Colors.green, size: 16),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bug_report), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
      final icon = wt.widget<Icon>(find.byIcon(Icons.bug_report));
      expect(icon.color, Colors.green);
    });
  });

  group('the gutter resolves the icon per issue type', () {
    const source = 'class A {\n  void m() {}\n}\n';

    Future<CodeController> mountGutter(
      WidgetTester wt,
      GutterStyle style,
    ) async {
      final analyzer = TestAnalyzer();
      analyzer.setIssues(const [
        Issue(line: 1, message: 'an error', type: IssueType.error),
        Issue(line: 2, message: 'some info', type: IssueType.info),
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

    testWidgets('a style supplied icon replaces the default', (wt) async {
      wt.view.physicalSize = const Size(800, 1000);
      wt.view.devicePixelRatio = 1.0;
      addTearDown(wt.view.reset);

      await mountGutter(wt, const GutterStyle(errorIcon: Icons.bug_report));

      expect(find.byIcon(Icons.bug_report), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      // Colour and size stay the gutter's own, whichever glyph resolves —
      // the same literals the errorIcon constant is built from.
      final overridden = wt.widget<Icon>(find.byIcon(Icons.bug_report));
      expect(overridden.color, _iconColor);
      expect(overridden.size, _iconSize);
      final fallback = wt.widget<Icon>(find.byIcon(Icons.cancel));
      expect(fallback.color, _iconColor);
      expect(fallback.size, _iconSize);
    });

    testWidgets('the icon is resolved per issue, not once per gutter', (
      wt,
    ) async {
      wt.view.physicalSize = const Size(800, 1000);
      wt.view.devicePixelRatio = 1.0;
      addTearDown(wt.view.reset);

      // Only infoIcon is supplied, so the error issue must keep the default
      // while the info issue takes the override. A single icon resolved once
      // for the whole gutter would show the same glyph for both.
      await mountGutter(wt, const GutterStyle(infoIcon: Icons.info_outline));

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      // Pin the gutter's own colour and size on the overridden path too, so
      // they cannot drift from the errorIcon constant in error.dart.
      final infoIcon = wt.widget<Icon>(find.byIcon(Icons.info_outline));
      expect(infoIcon.color, _iconColor);
      expect(infoIcon.size, _iconSize);
      final errorIcon = wt.widget<Icon>(find.byIcon(Icons.cancel));
      expect(errorIcon.color, _iconColor);
      expect(errorIcon.size, _iconSize);
    });
  });
}
