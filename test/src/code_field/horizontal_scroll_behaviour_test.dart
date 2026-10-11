import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import '../common/create_app.dart';

/// The code area's horizontal scroll position, driven through
/// `_horizontalCodeScroll` by the `SingleChildScrollView` in
/// `lib/src/code_field/code_field.dart`'s `_wrapInScrollView`.
///
/// Fork issue #85 reports horizontal scrolling as broken on iOS. It is not: the
/// code area scrolls on drag under an iOS platform override and does not under an
/// android one, because `TextField`'s `TapAndHorizontalDragGestureRecognizer`
/// claims the drag for text selection wherever `eagerVictoryOnDrag` is true
/// (`packages/flutter/lib/src/widgets/text_selection.dart:3731`). These tests pin
/// that platform split so it cannot regress invisibly, and pin the caret reveal
/// that already works, so neither half of the issue's story can drift without a
/// test failing.
///
/// Full measurements and the rejected fix options are in
/// `.specify/bugs/ios-horizontal-scroll-85/assessment.md`.

/// A line long enough that the code area has a real horizontal extent inside the
/// 300 px box the field is given.
final _longLine = 'a' * 300;

Finder get _horizontalScrollable =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal);

ScrollPosition _horizontalPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_horizontalScrollable.first).position;

Future<CodeController> _pumpField(
  WidgetTester tester, {
  required String text,
  bool wrap = false,
  FocusNode? focusNode,
}) async {
  final controller = createController(text);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 200,
          child: CodeField(
            controller: controller,
            wrap: wrap,
            focusNode: focusNode,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// A leftward drag across the code text, the way a user would try to scroll the
/// code area horizontally.
Future<void> _dragCodeLeft(WidgetTester tester) async {
  final topLeft = tester.getTopLeft(find.byType(TextField));
  final gesture = await tester.startGesture(
    Offset(topLeft.dx + 30, topLeft.dy + 30),
  );
  for (var i = 0; i < 12; i++) {
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('the code area scrolls horizontally on drag', () {
    testWidgets('under an iOS platform override', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // Reset in a finally, not an addTearDown: flutter_test's invariant check
      // runs before tear-down callbacks, so a leaked platform override is caught
      // here rather than cascading into the tests below.
      try {
        // No focus: an unfocused field does not reveal its caret, so the code
        // area starts at its left edge and the drag has somewhere to go.
        await _pumpField(tester, text: _longLine);
        expect(_horizontalPosition(tester).pixels, 0);

        await _dragCodeLeft(tester);

        expect(
          _horizontalPosition(tester).pixels,
          greaterThan(0),
          reason:
              'the drag must scroll the code area past the left edge of the text',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('an android platform override leaves the drag to text selection', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpField(tester, text: _longLine);
        expect(_horizontalPosition(tester).pixels, 0);

        await _dragCodeLeft(tester);

        // Flutter's own behaviour, not a defect this package can fix:
        // `TextField` claims the horizontal drag for text selection on android,
        // so the ancestor scroll view never sees it.
        expect(
          _horizontalPosition(tester).pixels,
          0,
          reason:
              'TextField claims the drag for text selection on non-Apple platforms',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('the caret is revealed horizontally', () {
    testWidgets('End, Home and the arrow keys move the code area', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final controller = await _pumpField(
        tester,
        text: _longLine,
        focusNode: focusNode,
      );

      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(
        controller.selection.start,
        _longLine.length,
        reason:
            'the caret starts at the end of the long line, so it must be revealed',
      );
      expect(
        _horizontalPosition(tester).pixels,
        greaterThan(0),
        reason: 'a caret past the right edge must be revealed',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(_horizontalPosition(tester).pixels, lessThan(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(
        _horizontalPosition(tester).pixels,
        greaterThan(0),
        reason: 'End moves the caret back past the right edge',
      );

      // Walk the caret back into view: the reveal must track it, not latch.
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(controller.selection.start, 30);
      expect(
        _horizontalPosition(tester).pixels,
        greaterThan(0),
        reason: 'a caret past the right edge must be revealed',
      );

      // The caret blink and the analysis debounce must not outlive the binding.
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('typing a long line ends with the caret in view', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await _pumpField(tester, text: '', focusNode: focusNode);

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), _longLine);
      await tester.pumpAndSettle();

      expect(
        _horizontalPosition(tester).pixels,
        greaterThan(0),
        reason: 'the caret is at the end of the typed line, revealed',
      );

      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
    });
  });

  group('the code area leaves it alone when there is nothing to scroll', () {
    testWidgets('content that fits the viewport', (tester) async {
      final controller = await _pumpField(tester, text: 'short');

      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pumpAndSettle();

      expect(_horizontalPosition(tester).maxScrollExtent, 0);
      expect(_horizontalPosition(tester).pixels, 0);
    });

    testWidgets('wrap: true reflows instead of scrolling', (tester) async {
      final controller = await _pumpField(tester, text: _longLine, wrap: true);

      controller.selection = const TextSelection.collapsed(offset: 299);
      await tester.pumpAndSettle();

      expect(
        _horizontalScrollable,
        findsNothing,
        reason:
            'wrap: true reflows the text to the viewport width, so the code area '
            'has no horizontal scroll view to drive',
      );
    });
  });
}
