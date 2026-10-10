import 'package:flutter/widgets.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

void main() {
  group('Tab never survives into the code (#20)', () {
    test('Loading text with tabs converts them to spaces', () {
      final controller = createController('int\tx;');

      expect(controller.text, 'int  x;');
      expect(controller.text.contains('\t'), isFalse);
      controller.dispose();
    });

    test('The Tab keypress inserts spaces, not a tab', () {
      final controller = createController('ab');
      controller.selection = const TextSelection.collapsed(offset: 1);

      controller.value = const TextEditingValue(
        text: 'a\tb',
        selection: TextSelection.collapsed(offset: 2),
      );

      expect(controller.text, 'a  b');
      controller.dispose();
    });

    test('A tab delivered by the platform while composing is converted', () {
      final controller = createController('ab');
      controller.selection = const TextSelection.collapsed(offset: 2);

      controller.value = const TextEditingValue(
        text: 'ab\t',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 2, end: 3),
      );

      expect(controller.text, 'ab  ');
      expect(controller.text.contains('\t'), isFalse);
      controller.dispose();
    });

    test('A tab inside committed composing text is converted', () {
      final controller = createController('ab');

      controller.value = const TextEditingValue(
        text: 'ab\tx',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      );
      controller.value = const TextEditingValue(
        text: 'ab\tx',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange.empty,
      );

      expect(controller.text, 'ab  x');
      expect(controller.text.contains('\t'), isFalse);
      controller.dispose();
    });
    test('Without TabModifier the tabs are left to the consumer', () {
      final controller = CodeController(
        text: 'ab',
        modifiers: const [],
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
      );

      controller.value = const TextEditingValue(
        text: 'ab\t',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 2, end: 3),
      );

      expect(controller.text, 'ab\t');
      controller.dispose();
    });
  });
}
