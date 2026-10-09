import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/analyzer/models/issue.dart';
import 'package:zuraffa_code_editor/src/analyzer/models/issue_type.dart';
import 'package:zuraffa_code_editor/src/gutter/clickable.dart';
import 'package:zuraffa_code_editor/src/gutter/error.dart';

const _style = TextStyle(
  fontSize: 12,
  color: Colors.black,
  backgroundColor: Colors.white,
);

/// Mounts a [GutterErrorWidget] with a mouse pointer, opened and closed the
/// same way the dispose-regression test does.
Future<WidgetTester> _mount(WidgetTester wt, Issue issue) async {
  await wt.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: GutterErrorWidget(issue, _style))),
    ),
  );
  return wt;
}

Future<TestGesture> _mouse(WidgetTester wt) async {
  final gesture = await wt.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  group('GutterErrorWidget popup content', () {
    testWidgets('renders the message, the url and the suggestion', (wt) async {
      const issue = Issue(
        line: 3,
        message: 'Unused import',
        type: IssueType.warning,
        suggestion: 'Remove the import',
        url: 'https://dart.dev/tools/diagnostic-messages',
      );
      await _mount(wt, issue);

      final gesture = await _mouse(wt);
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();

      expect(find.text('Unused import'), findsOneWidget);
      expect(
        find.text('https://dart.dev/tools/diagnostic-messages'),
        findsOneWidget,
      );
      // A divider separates the message from the suggestion.
      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('Remove the import'), findsOneWidget);
    });

    testWidgets('omits the url and the divider when the issue has none', (
      wt,
    ) async {
      const issue = Issue(
        line: 1,
        message: 'Plain error',
        type: IssueType.error,
      );
      await _mount(wt, issue);

      final gesture = await _mouse(wt);
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();

      expect(find.text('Plain error'), findsOneWidget);
      expect(find.byType(ClickableWidget), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('renders a suggestion without a url', (wt) async {
      const issue = Issue(
        line: 2,
        message: 'Dead code',
        type: IssueType.info,
        suggestion: 'Delete it',
      );
      await _mount(wt, issue);

      final gesture = await _mouse(wt);
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();

      expect(find.text('Delete it'), findsOneWidget);
      expect(find.byType(ClickableWidget), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('GutterErrorWidget interaction', () {
    testWidgets('the popup survives the pointer moving onto it', (wt) async {
      const issue = Issue(line: 1, message: 'Hover me', type: IssueType.error);
      await _mount(wt, issue);

      final gesture = await _mouse(wt);
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();
      expect(find.text('Hover me'), findsOneWidget);

      // Entering the popup itself marks `_mouseEnteredPopup = true`, so the
      // delayed close from leaving the icon is cancelled.
      final popupText = find.text('Hover me');
      final popupCenter = wt.getCenter(popupText);
      await gesture.moveTo(popupCenter);
      await wt.pump();

      // Now leave both: the icon's delayed close runs, but the popup's own
      // onExit removes it anyway.
      await gesture.moveTo(const Offset(-500, -500));
      await wt.pump(const Duration(milliseconds: 60));

      expect(find.text('Hover me'), findsNothing);
    });

    testWidgets('entering the popup keeps it open past the 50ms delay', (
      wt,
    ) async {
      const issue = Issue(line: 1, message: 'Stay open', type: IssueType.error);
      await _mount(wt, issue);

      final gesture = await _mouse(wt);
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();

      // Move onto the popup, then let the icon's 50ms close timer fire while
      // the pointer is still on the popup.
      await gesture.moveTo(wt.getCenter(find.text('Stay open')));
      await wt.pump();
      await wt.pump(const Duration(milliseconds: 60));

      expect(
        find.text('Stay open'),
        findsOneWidget,
        reason: '_mouseEnteredPopup must keep the entry alive',
      );

      // Leaving the popup itself closes it immediately.
      await gesture.moveTo(const Offset(-500, -500));
      await wt.pump();
      expect(find.text('Stay open'), findsNothing);
    });

    testWidgets('hovering the icon twice does not stack popups', (wt) async {
      const issue = Issue(line: 1, message: 'Once', type: IssueType.error);
      await _mount(wt, issue);

      final gesture = await _mouse(wt);
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();
      await wt.pump(const Duration(milliseconds: 60));

      // Re-enter while the entry already exists: the `_entry != null` guard
      // must short-circuit instead of inserting a second one.
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();

      expect(find.text('Once'), findsOneWidget);
    });

    testWidgets('tapping the url launches it', (wt) async {
      const url = 'https://dart.dev/tools/diagnostic-messages';
      const issue = Issue(
        line: 1,
        message: 'Has a link',
        type: IssueType.error,
        url: url,
      );
      await _mount(wt, issue);

      final gesture = await _mouse(wt);
      await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
      await wt.pump();

      final launches = <MethodCall>[];
      wt.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launches.add(call);
          return true;
        },
      );
      addTearDown(() {
        wt.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
      });

      await wt.tap(find.text(url));
      await wt.pump();

      expect(launches, isNotEmpty, reason: 'tapping the link launches the url');
      expect(
        launches.first.method,
        anyOf('launch', 'launchUrl'),
        reason: 'url_launcher v6 dispatches through the url_launcher channel',
      );
    });
  });
}
