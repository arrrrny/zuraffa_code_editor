import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import '../common/text_editing_value.dart';

const _twoIdenticalBlocks = '''
void a() {
  int x = 1;
}
void a() {
  int x = 1;
}
''';

void main() {
  group('Folds survive edits of identical text.', () {
    test('Deleting one of two identical folded blocks unfolds the other', () {
      final controller = CodeController(
        text: _twoIdenticalBlocks,
        language: java,
      );
      controller.foldAt(0);
      const firstBlockText = 'void a() {}\n';

      expect(
        controller.text,
        startsWith(firstBlockText),
        reason: 'Precondition: the first block is folded to its first line',
      );

      // The user selects the folded-away block, which is visible only through
      // its first line, and deletes it.
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: firstBlockText.length,
      );
      controller.value = controller.value.replacedSelection('');

      expect(
        controller.code.foldedBlocks,
        isEmpty,
        reason:
            'The block that was folded is the one that was deleted; the '
            'surviving block is a different block that was never folded',
      );
      expect(
        controller.text,
        'void a() {\n  int x = 1;\n}\n',
        reason: 'The surviving block is not folded away either',
      );

      controller.dispose();
    });

    test('A folded block survives an edit well away from it', () {
      const example = 'void a() {\n  int x = 1;\n}\nint y = 2;\n';
      final controller = CodeController(text: example, language: java);
      controller.foldAt(0);

      final visible = controller.text;
      controller.selection = TextSelection(
        baseOffset: visible.indexOf('2'),
        extentOffset: visible.indexOf('2') + 1,
      );
      controller.value = controller.value.replacedSelection('3');

      expect(
        controller.code.foldedBlocks,
        hasLength(1),
        reason: 'The edit is below the block, not inside it',
      );
      expect(controller.text, 'void a() {}\nint y = 3;\n');

      controller.dispose();
    });

    test('A folded block survives an edit on its own first line', () {
      const example = 'void a() {\n  int x = 1;\n}\n';
      final controller = CodeController(text: example, language: java);
      controller.foldAt(0);

      controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 6,
      );
      controller.value = controller.value.replacedSelection('b');

      expect(
        controller.code.foldedBlocks,
        hasLength(1),
        reason: 'The visible first line is not the hidden content',
      );
      expect(controller.text, 'void b() {}\n');

      controller.dispose();
    });

    test('A folded block does not survive a change of its hidden content', () {
      const example = 'void a() {\n  int x = 1;\n}\n';
      final controller = CodeController(text: example, language: java);
      controller.foldAt(0);

      controller.fullText = 'void a() {\n  int x = 2;\n}\n';

      expect(
        controller.code.foldedBlocks,
        isEmpty,
        reason: 'The content the fold hides is what changed',
      );

      controller.dispose();
    });
  });
}
