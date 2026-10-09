import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

void main() {
  group('CodeController. IME composition.', () {
    test('Composing-only updates are applied', () {
      final controller = createController('');

      controller.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 1),
      );

      controller.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );

      expect(
        controller.value.composing,
        const TextRange(start: 0, end: 2),
        reason: 'A composing-only platform update must reach the engine',
      );
      controller.dispose();
    });

    test('Composing text is committed correctly after IME selection', () {
      final controller = createController('}');
      controller.selection = const TextSelection.collapsed(offset: 1);

      controller.value = const TextEditingValue(
        text: '} ni',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      );

      controller.value = const TextEditingValue(
        text: '} 你',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange.empty,
      );

      expect(controller.text, '} 你');
      expect(controller.fullText, '} 你');
      expect(controller.value.composing, TextRange.empty);
      controller.dispose();
    });

    test(
      'Typing with an IME while a block is folded keeps the folded code',
      () {
        final controller = createController(
          '// a\n// b\nint x = 1;\nvoid main() {}\n',
        );
        controller.foldCommentAtLineZero();

        final visible = controller.text;
        expect(
          visible.contains('// b'),
          false,
          reason: 'Precondition: the block is folded',
        );
        controller.selection = TextSelection.collapsed(offset: visible.length);

        controller.value = TextEditingValue(
          text: '${visible}ni',
          selection: TextSelection.collapsed(offset: visible.length + 2),
          composing: TextRange(start: visible.length, end: visible.length + 2),
        );

        controller.value = TextEditingValue(
          text: '$visible 你',
          selection: TextSelection.collapsed(offset: visible.length + 2),
          composing: TextRange.empty,
        );

        expect(
          controller.fullText,
          '// a\n// b\nint x = 1;\nvoid main() {}\n',
          reason: 'Folded content must not be dropped by IME input',
        );
        expect(controller.text, '$visible 你');
        controller.dispose();
      },
    );

    test('The autocomplete popup is hidden when a composition commits', () {
      final controller = createController('');
      controller.popupController.show(['one', 'two']);

      controller.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );

      expect(
        controller.popupController.shouldShow,
        true,
        reason: 'Precondition: the popup is open during composition',
      );

      controller.value = const TextEditingValue(
        text: '你',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange.empty,
      );

      expect(
        controller.popupController.shouldShow,
        false,
        reason:
            'The commit must drop suggestions computed before the composition',
      );
      controller.dispose();
    });

    test('Modifiers do not fire while composing', () {
      final controller = createController('a');
      controller.selection = const TextSelection.collapsed(offset: 1);

      controller.value = const TextEditingValue(
        text: 'a(',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      );

      expect(
        controller.text,
        'a(',
        reason: 'The paired-symbol modifier must not touch a composition',
      );
      expect(controller.fullText, 'a(');
      controller.dispose();
    });

    test('A transient out-of-range selection during composition '
        'is applied without throwing', () {
      final controller = createController('}');
      controller.selection = const TextSelection.collapsed(offset: 1);

      controller.value = const TextEditingValue(
        text: '} ni',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      );

      // The composition shrank but the platform selection still points
      // past the end of the new text.
      controller.value = const TextEditingValue(
        text: '} n',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 2, end: 3),
      );

      expect(controller.text, '} n');
      controller.dispose();
    });

    test('readOnly ignores text changes during composition', () {
      final controller = CodeController(
        text: 'abc',
        readOnly: true,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
      );
      controller.selection = const TextSelection.collapsed(offset: 3);

      controller.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 3, end: 3),
      );

      controller.value = const TextEditingValue(
        text: 'abcd',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 3, end: 4),
      );

      expect(
        controller.text,
        'abc',
        reason: 'A read-only field must not accept composition text',
      );
      controller.dispose();
    });

    test('Enter and Tab actions are ignored during composition', () {
      final controller = createController('');

      controller.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );

      controller.onEnterKeyAction();
      expect(controller.text, 'ni');

      controller.onTabKeyAction();
      expect(controller.text, 'ni');
      controller.dispose();
    });

    test('onKey ignores the autocomplete popup during composition', () {
      final controller = createController('');
      controller.popupController.show(['one', 'two']);

      controller.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );

      final result = controller.onKey(
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
        ),
      );

      expect(result, KeyEventResult.ignored);
      expect(controller.popupController.selectedIndex, 0);
      controller.dispose();
    });

    testWidgets('buildTextSpan is composing-aware while composing', (wt) async {
      final controller = createController('int n;');
      controller.selection = const TextSelection.collapsed(offset: 4);

      await wt.pumpWidget(createApp(controller, focusNode));
      final context = wt.element(find.byType(CodeField));

      final plainComposing = TextEditingController();
      plainComposing.value = const TextEditingValue(
        text: 'int n;',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 4, end: 5),
      );
      final plainComposingSpan = plainComposing.buildTextSpan(
        context: context,
        withComposing: true,
      );

      final highlighted = controller.buildTextSpan(
        context: context,
        withComposing: true,
      );
      expect(
        highlighted.children?.isNotEmpty ?? false,
        true,
        reason: 'Without a composition the highlighted span is used',
      );

      controller.value = const TextEditingValue(
        text: 'int n;',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 4, end: 5),
      );

      final composing = controller.buildTextSpan(
        context: context,
        withComposing: true,
      );
      expect(
        composing.toPlainText(),
        plainComposingSpan.toPlainText(),
        reason:
            'While composing the span must delegate to the default '
            'implementation',
      );
      expect(composing.children?.length, plainComposingSpan.children?.length);
      plainComposing.dispose();
    });

    testWidgets('Enter does not reach the editor while composing', (wt) async {
      final controller = createController('');
      focusNode = FocusNode();
      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();
      await wt.pump();

      controller.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      await wt.pump();

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pump();

      expect(controller.text, 'ni');
      expect(controller.value.composing, const TextRange(start: 0, end: 2));
    });
  });
}
