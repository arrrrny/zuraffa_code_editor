import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa_code_editor/src/gutter/error.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

const _message = 'Unused import';
const _popupStyle = TextStyle(
  fontSize: 12,
  color: Colors.amber,
  backgroundColor: Colors.white,
);

class TestAnalyzer extends Mock implements AbstractAnalyzer {
  void setIssues(List<Issue> issues) {
    // ignore: discarded_futures
    when(
      () => analyze(any()),
    ).thenAnswer((_) async => AnalysisResult(issues: issues));
  }
}

/// The decoration the popup container actually rendered.
///
/// The popup's message is the only `Text` inside the decorated `Container`, so
/// walking up from it lands on the popup container and not on any other box in
/// the tree.
BoxDecoration _renderedDecoration(WidgetTester wt) {
  final container = wt.widget<Container>(
    find
        .ancestor(of: find.text(_message), matching: find.byType(Container))
        .first,
  );
  return container.decoration! as BoxDecoration;
}

Future<TestGesture> _enterPopup(WidgetTester wt) async {
  final gesture = await wt.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
  await wt.pump();
  return gesture;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Code.empty);
  });

  group('the default derivation is unchanged', () {
    testWidgets('takes its colour from the popup text style', (wt) async {
      await wt.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GutterErrorWidget(
                Issue(line: 1, message: _message, type: IssueType.warning),
                _popupStyle,
              ),
            ),
          ),
        ),
      );
      await _enterPopup(wt);

      expect(_renderedDecoration(wt).color, _popupStyle.backgroundColor);
    });

    testWidgets('borders with the text colour when there is one', (wt) async {
      await wt.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GutterErrorWidget(
                Issue(line: 1, message: _message, type: IssueType.warning),
                _popupStyle,
              ),
            ),
          ),
        ),
      );
      await _enterPopup(wt);

      final border = _renderedDecoration(wt).border;
      expect(border, isA<Border>());
      expect((border as Border).top.color, _popupStyle.color);
    });

    testWidgets('has no border when the text colour is null', (wt) async {
      await wt.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GutterErrorWidget(
                Issue(line: 1, message: _message, type: IssueType.warning),
                TextStyle(color: null, backgroundColor: Colors.white),
              ),
            ),
          ),
        ),
      );
      await _enterPopup(wt);

      expect(_renderedDecoration(wt).border, isNull);
    });
  });

  group('GutterErrorWidget.popupDecoration', () {
    testWidgets('replaces the derived decoration', (wt) async {
      const custom = BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      );

      await wt.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GutterErrorWidget(
                Issue(line: 1, message: _message, type: IssueType.warning),
                _popupStyle,
                popupDecoration: custom,
              ),
            ),
          ),
        ),
      );
      await _enterPopup(wt);

      final decoration = _renderedDecoration(wt);
      expect(decoration.color, Colors.black);
      expect(decoration.borderRadius, custom.borderRadius);
    });

    testWidgets('leaves the popup content alone', (wt) async {
      const issue = Issue(
        line: 1,
        message: _message,
        type: IssueType.warning,
        suggestion: 'Remove the import',
        url: 'https://dart.dev/tools/diagnostic-messages',
      );

      await wt.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GutterErrorWidget(
                issue,
                _popupStyle,
                popupDecoration: BoxDecoration(color: Colors.black),
              ),
            ),
          ),
        ),
      );
      await _enterPopup(wt);

      expect(find.text(_message), findsOneWidget);
      expect(
        find.text('https://dart.dev/tools/diagnostic-messages'),
        findsOneWidget,
      );
      expect(find.text('Remove the import'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('GutterStyle.errorPopupDecoration', () {
    const source = 'class A {\n  void m() {}\n}\n';

    testWidgets('reaches the gutter popups', (wt) async {
      wt.view.physicalSize = const Size(800, 1000);
      wt.view.devicePixelRatio = 1.0;
      addTearDown(wt.view.reset);

      final analyzer = TestAnalyzer();
      analyzer.setIssues(const [
        Issue(line: 1, message: _message, type: IssueType.error),
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
              gutterStyle: GutterStyle(
                errorPopupTextStyle: _popupStyle,
                errorPopupDecoration: const BoxDecoration(color: Colors.black),
              ),
            ),
          ),
        ),
      );
      await wt.pumpAndSettle();
      await _enterPopup(wt);

      expect(_renderedDecoration(wt).color, Colors.black);
    });

    test('is carried by copyWith', () {
      const style = GutterStyle(
        errorPopupDecoration: BoxDecoration(color: Colors.black),
      );

      expect(style.copyWith().errorPopupDecoration?.color, Colors.black);
      expect(
        style
            .copyWith(
              errorPopupDecoration: const BoxDecoration(color: Colors.white),
            )
            .errorPopupDecoration
            ?.color,
        Colors.white,
      );
    });

    testWidgets('two issues on different lines share one decoration', (
      wt,
    ) async {
      wt.view.physicalSize = const Size(800, 1000);
      wt.view.devicePixelRatio = 1.0;
      addTearDown(wt.view.reset);

      final analyzer = TestAnalyzer();
      analyzer.setIssues(const [
        Issue(line: 1, message: 'first', type: IssueType.error),
        Issue(line: 2, message: 'second', type: IssueType.warning),
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
              gutterStyle: GutterStyle(
                errorPopupTextStyle: _popupStyle,
                errorPopupDecoration: const BoxDecoration(color: Colors.black),
              ),
            ),
          ),
        ),
      );
      await wt.pumpAndSettle();

      final gesture = await wt.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      BoxDecoration decorationFor(String message) {
        final container = wt.widget<Container>(
          find
              .ancestor(
                of: find.text(message),
                matching: find.byType(Container),
              )
              .first,
        );
        return container.decoration! as BoxDecoration;
      }

      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget).first));
      await wt.pump();
      final first = decorationFor('first');

      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget).last));
      // Leaving the first icon schedules its popup's delayed 50 ms close; flush
      // it so no timer is left pending when the tree is disposed.
      await wt.pump(const Duration(milliseconds: 100));
      final second = decorationFor('second');

      expect(second, first);
    });
  });
}
