import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import '../common/create_app.dart';
import '../common/snippets.dart';

/// The value the platform delivers for one character typed at [caret].
TextEditingValue _typedAt(String oldText, String char, int caret) {
  return TextEditingValue(
    text: oldText.replaceRange(caret, caret, char),
    selection: TextSelection.collapsed(offset: caret + 1),
  );
}

void main() {
  group('CodeController. Insert toggles overtype.', () {
    testWidgets('Overtype is off by default', (WidgetTester wt) async {
      final controller = await pumpController(wt, 'int a = 1;');

      expect(
        controller.isOvertypeMode,
        false,
        reason: 'The editor must start in insert mode',
      );
    });

    testWidgets('Pressing Insert once turns overtype on', (
      WidgetTester wt,
    ) async {
      final controller = await pumpController(wt, 'int a = 1;');
      await wt.pump();

      await wt.sendKeyEvent(LogicalKeyboardKey.insert);

      expect(controller.isOvertypeMode, true);
    });

    testWidgets('Pressing Insert again returns to insert mode', (
      WidgetTester wt,
    ) async {
      final controller = await pumpController(wt, 'int a = 1;');
      await wt.pump();

      await wt.sendKeyEvent(LogicalKeyboardKey.insert);
      await wt.sendKeyEvent(LogicalKeyboardKey.insert);

      expect(controller.isOvertypeMode, false);
    });

    testWidgets('Ctrl-Insert still copies instead of toggling overtype', (
      WidgetTester wt,
    ) async {
      final controller = await pumpController(wt, 'int a = 1;');
      await wt.pump();

      await wt.sendKeyDownEvent(LogicalKeyboardKey.control);
      await wt.sendKeyEvent(LogicalKeyboardKey.insert);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.control);

      expect(
        controller.isOvertypeMode,
        false,
        reason: 'Ctrl-Insert is copy, not overtype',
      );
    });

    testWidgets('Insert does not toggle overtype while composing', (
      WidgetTester wt,
    ) async {
      final controller = await pumpController(wt, 'int a = 1;');
      await wt.pump();
      controller.value = const TextEditingValue(
        text: 'int a = 1;ni',
        selection: TextSelection.collapsed(offset: 11),
        composing: TextRange(start: 10, end: 12),
      );
      await wt.pump();

      await wt.sendKeyEvent(LogicalKeyboardKey.insert);

      expect(
        controller.isOvertypeMode,
        false,
        reason: 'A keystroke meant for the IME must not reach the toggle',
      );
      expect(
        controller.value.composing,
        const TextRange(start: 10, end: 12),
        reason: 'The composition survives the unhandled keystroke',
      );
    });

    test('The setter and toggleOvertypeMode drive the same flag', () {
      final controller = createController('int a = 1;');

      expect(controller.isOvertypeMode, false);

      controller.isOvertypeMode = true;
      expect(controller.isOvertypeMode, true);

      controller.toggleOvertypeMode();
      expect(controller.isOvertypeMode, false);

      controller.isOvertypeMode = true;
      controller.toggleOvertypeMode();
      expect(controller.isOvertypeMode, false);

      controller.dispose();
    });
  });

  group('CodeController. Overtype replaces.', () {
    test('Overtype replaces the character after the caret', () {
      final controller = createController('int a = 1;');
      controller.isOvertypeMode = true;
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.value = _typedAt(controller.text, 'x', 4);

      expect(controller.text, 'int x = 1;');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
      controller.dispose();
    });

    test('Overtype inserts past the last character', () {
      final controller = createController('int a = 1;');
      controller.isOvertypeMode = true;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );

      controller.value = _typedAt(controller.text, 'x', controller.text.length);

      expect(controller.text, 'int a = 1;x');
      controller.dispose();
    });

    test('Overtype replaces under a folded block', () {
      final controller = createController(MethodSnippet.full);
      controller.foldAt(1);
      controller.isOvertypeMode = true;

      final visible = controller.text;
      final caret = visible.indexOf(' ');
      controller.selection = TextSelection.collapsed(offset: caret);

      controller.value = _typedAt(visible, 'x', caret);

      expect(
        controller.text[caret],
        'x',
        reason: 'The visible character at the caret is replaced, not shifted',
      );
      expect(
        controller.fullText.length,
        MethodSnippet.full.length,
        reason: 'The folded body must not grow or shrink',
      );
      controller.dispose();
    });

    test('Overtype does not replace a selection', () {
      final controller = createController('int a = 1;');
      controller.isOvertypeMode = true;

      controller.value = TextEditingValue(
        text: 'x = 1;',
        selection: const TextSelection.collapsed(offset: 1),
      );

      expect(
        controller.text,
        'x = 1;',
        reason: 'Typing over a selection replaces the selection as usual',
      );
      controller.dispose();
    });

    test('An auto-paired keystroke keeps its pair under overtype', () {
      const caret = 4;
      final paired = createController('int a = 1;');
      paired.selection = const TextSelection.collapsed(offset: caret);
      paired.value = _typedAt(paired.text, '(', caret);

      final overtyped = createController('int a = 1;');
      overtyped.isOvertypeMode = true;
      overtyped.selection = const TextSelection.collapsed(offset: caret);
      overtyped.value = _typedAt(overtyped.text, '(', caret);

      expect(
        overtyped.text,
        paired.text,
        reason:
            'The pair is a modifier transform, not a one-character insertion, '
            'so overtype has nothing to replace with',
      );
      expect(overtyped.selection, paired.selection);

      paired.dispose();
      overtyped.dispose();
    });

    test('A deletion is not an overtype', () {
      final controller = createController('int a = 1;');
      controller.isOvertypeMode = true;

      controller.value = const TextEditingValue(
        text: 'int a = 1',
        selection: TextSelection.collapsed(offset: 9),
      );

      expect(controller.text, 'int a = 1');
      controller.dispose();
    });

    test('An insertion away from the caret is not an overtype', () {
      final controller = createController('int a = 1;');
      controller.isOvertypeMode = true;
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.value = const TextEditingValue(
        text: 'xint a = 1;',
        selection: TextSelection.collapsed(offset: 0),
      );

      expect(controller.text, 'xint a = 1;');
      controller.dispose();
    });

    test('A read-only controller does not overtype', () {
      final controller = CodeController(
        text: 'int a = 1;',
        language: java,
        readOnly: true,
      );
      controller.isOvertypeMode = true;
      controller.selection = const TextSelection.collapsed(offset: 4);

      controller.value = _typedAt(controller.text, 'x', 4);

      expect(controller.text, 'int a = 1;');
      controller.dispose();
    });
  });
}
