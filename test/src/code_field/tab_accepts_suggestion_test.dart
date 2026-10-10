import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// #36 — accept an autocomplete suggestion with Tab.
///
/// Upstream `akvelon/flutter-code-editor#188` asked for the suggestion list to
/// be committable with Tab. It works on this fork, so these tests pin the
/// behaviour rather than build it: Tab is bound to `TabKeyIntent`, whose action
/// calls `CodeController.onTabKeyAction()`, and that method prefers
/// `insertSelectedWord()` while the popup is showing and falls back to inserting
/// the editor's indent otherwise.
///
/// The popup has to be in its showing state for these to mean anything, so each
/// test seeds a caret first: the field's own controller starts with a
/// `TextSelection.invalid`, and the framework's first value round-trip reads as a
/// selection change, which `CodeController.value`'s setter answers by hiding the
/// popup again. Setting a real selection before `show()` leaves nothing for that
/// branch to hide.
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

  group('Tab accepts the suggestion (#36)', () {
    testWidgets('and hides the popup', (wt) async {
      final controller = await pumpEditor(wt);
      await showSuggestions(wt, controller, ['alpha', 'beta']);

      await wt.sendKeyEvent(LogicalKeyboardKey.tab);
      await wt.pumpAndSettle();

      expect(
        controller.text,
        'alpha ',
        reason: 'the highlighted suggestion replaces the word under the caret',
      );
      expect(controller.selection.baseOffset, 6);
      expect(
        controller.popupController.shouldShow,
        isFalse,
        reason: 'committing a suggestion closes the popup',
      );
    });

    testWidgets('the suggestion the arrows moved to, not the first one', (
      wt,
    ) async {
      final controller = await pumpEditor(wt);
      await showSuggestions(wt, controller, ['alpha', 'beta', 'gamma']);

      await wt.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await wt.pumpAndSettle();
      expect(controller.popupController.selectedIndex, 1);

      await wt.sendKeyEvent(LogicalKeyboardKey.tab);
      await wt.pumpAndSettle();

      expect(controller.text, 'beta ');
    });

    testWidgets('Enter still commits as well', (wt) async {
      final controller = await pumpEditor(wt);
      await showSuggestions(wt, controller, ['alpha']);

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pumpAndSettle();

      expect(controller.text, 'alpha ');
      expect(controller.popupController.shouldShow, isFalse);
    });
  });

  group('Tab without a suggestion to accept (#36)', () {
    testWidgets('inserts the editor indent', (wt) async {
      final controller = await pumpEditor(wt);

      await wt.sendKeyEvent(LogicalKeyboardKey.tab);
      await wt.pumpAndSettle();

      expect(controller.text, 'al${' ' * controller.params.tabSpaces}');
      expect(controller.popupController.shouldShow, isFalse);
    });

    testWidgets('a disabled popup is not an acceptance', (wt) async {
      final controller = await pumpEditor(wt);
      // `PopupController.show` has no emptiness branch — with `enabled` true it
      // sets `shouldShow` for any list. The field's empty-results guard lives in
      // `generateSuggestions` (show when non-empty, hide otherwise); this test
      // pins the disabled-popup path instead.
      controller.popupController.enabled = false;
      controller.popupController.show(['alpha']);
      await wt.pumpAndSettle();
      expect(controller.popupController.shouldShow, isFalse);

      await wt.sendKeyEvent(LogicalKeyboardKey.tab);
      await wt.pumpAndSettle();

      expect(controller.text, 'al${' ' * controller.params.tabSpaces}');
    });
  });
}
