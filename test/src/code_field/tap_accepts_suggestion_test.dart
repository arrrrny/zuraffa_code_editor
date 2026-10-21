import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// #84 — a single tap accepts an autocomplete suggestion, and the popup shows
/// where it can be read.
///
/// Upstream `akvelon/flutter-code-editor#205` reported that on mobile the
/// dropdown needed a double tap and got cut off. These drive the real field:
/// the tap goes through `wt.tap` (the touch path, not a synthesised mouse
/// click), and the popup's rows are measured in the window the way a phone
/// squeezed by its own keyboard would see them.
///
/// The popup has to be in its showing state for these to mean anything, so
/// each test seeds a caret first: the field's controller starts with a
/// `TextSelection.invalid`, and the framework's first value round-trip reads
/// as a selection change, which `CodeController.value`'s setter answers by
/// hiding the popup again. Setting a real selection before `show()` leaves
/// nothing for that branch to hide.
void main() {
  Future<CodeController> pumpEditor(WidgetTester wt) async {
    final controller = await pumpController(wt, 'al');
    controller.selection = const TextSelection.collapsed(offset: 2);
    await wt.pumpAndSettle();
    return controller;
  }

  Future<void> showSuggestions(
    WidgetTester wt,
    CodeController controller,
    List<String> suggestions,
  ) async {
    controller.popupController.show(suggestions);
    await wt.pumpAndSettle();
  }

  List<Rect> suggestionRows(WidgetTester wt) {
    final rows = find.byType(InkWell);
    return [
      for (var i = 0; i < rows.evaluate().length; i++) wt.getRect(rows.at(i)),
    ];
  }

  group('A single tap accepts the suggestion (#84)', () {
    testWidgets('and hides the popup', (wt) async {
      final controller = await pumpEditor(wt);
      await showSuggestions(wt, controller, ['alpha', 'beta', 'gamma']);

      await wt.tap(find.text('beta'));
      await wt.pumpAndSettle();

      expect(
        controller.text,
        'beta ',
        reason: 'the tapped suggestion replaces the word under the caret',
      );
      expect(controller.popupController.shouldShow, isFalse);
    });

    testWidgets('without waiting for the double tap timeout', (wt) async {
      final controller = await pumpEditor(wt);
      await showSuggestions(wt, controller, ['alpha', 'beta']);

      await wt.tap(find.text('alpha'));
      // kDoubleTapTimeout is 300 ms: a pump well under it must already see the
      // commit, or the gesture arena is still holding the tap back.
      await wt.pump(const Duration(milliseconds: 100));

      expect(controller.text, 'alpha ');
    });

    testWidgets('the arrows + Enter path is unchanged', (wt) async {
      final controller = await pumpEditor(wt);
      await showSuggestions(wt, controller, ['alpha', 'beta', 'gamma']);

      await wt.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await wt.pumpAndSettle();
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await wt.pumpAndSettle();
      expect(controller.popupController.selectedIndex, 2);

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pumpAndSettle();

      expect(controller.text, 'gamma ');
      expect(controller.popupController.shouldShow, isFalse);
    });
  });

  group('The popup stays inside the window (#84)', () {
    testWidgets('on a window too narrow for it and a full line of code', (
      wt,
    ) async {
      wt.view.physicalSize = const Size(300, 600);
      wt.view.devicePixelRatio = 1.0;
      addTearDown(wt.view.reset);

      final controller = await pumpController(wt, 'a' * 40);
      controller.selection = const TextSelection.collapsed(offset: 40);
      await wt.pumpAndSettle();
      await showSuggestions(wt, controller, ['alpha', 'beta']);

      // The old clamp put the popup at 300 - 300 + editorOffset.dx - 100: a
      // negative left edge on any phone-sized editor.
      for (final row in suggestionRows(wt)) {
        expect(row.left, greaterThanOrEqualTo(0));
        expect(row.right, lessThanOrEqualTo(300));
      }
    });

    testWidgets('above a caret near the bottom of a short editor', (wt) async {
      final controller = createController('al');
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      // An editor shorter than the popup's max height, pinned to the bottom of
      // the window: the flip used to be refused outright (100 < 80) and the
      // rows ran past the bottom edge.
      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 390,
                height: 80,
                child: CodeField(
                  renderer: CodeFieldRenderer.textField,
                  controller: controller,
                  focusNode: focusNode,
                ),
              ),
            ),
          ),
        ),
      );
      await wt.pumpAndSettle();
      // Seeded after the field is laid out: the controller's listeners only
      // reach the field once it is built.
      controller.selection = const TextSelection.collapsed(offset: 2);
      await wt.pumpAndSettle();
      await showSuggestions(wt, controller, ['alpha', 'beta', 'gamma']);

      final positioned = wt.widget<Positioned>(find.byType(Positioned));
      expect(
        positioned.top,
        lessThan(500),
        reason: 'the popup is flipped up, not left running past the bottom',
      );
      for (final row in suggestionRows(wt)) {
        expect(row.bottom, lessThanOrEqualTo(600));
      }
    });

    testWidgets('below a caret with room under it', (wt) async {
      final controller = await pumpEditor(wt);
      await showSuggestions(wt, controller, ['alpha', 'beta', 'gamma']);

      final rows = suggestionRows(wt);
      expect(
        rows.first.top,
        greaterThan(30),
        reason:
            'the popup hangs off the caret near the top of the field, '
            'not shoved to the top of the window',
      );
      for (final row in rows) {
        expect(row.bottom, lessThanOrEqualTo(600));
      }
    });
  });
}
