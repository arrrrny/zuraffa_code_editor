library;

import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import '../common/text_editing_value.dart';

/// Deleting a newline that sits *next to* a folded block must not drop the
/// fold. The block's hidden content is untouched by such an edit, and the
/// block still exists afterwards, so it must keep re-matching.
///
/// akvelon/flutter-code-editor#175.
void main() {
  group('A fold survives a deletion next to it.', () {
    test('Deleting the newline right after the closer row', () {
      const example = 'a {\n  body();\n}\n\n\n\nb {\n  y();\n}\n';
      final controller = CodeController(text: example, language: java);
      controller.foldAt(0);
      // visible = `a {}\n\n\n\nb {\n  y();\n}\n`, so visible 4..5 is the
      // newline that ends the folded block's closer row.
      expect(
        controller.code.hiddenRanges.ranges,
        hasLength(1),
        reason: 'Precondition: the block is folded away',
      );

      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 5,
      );
      controller.value = controller.value.replacedSelection('');

      expect(
        controller.text,
        'a {}\n\n\nb {\n  y();\n}\n',
        reason: 'The newline is deleted, one blank line goes with it',
      );
      expect(
        controller.code.hiddenRanges.ranges,
        hasLength(1),
        reason:
            'The fold hid `  body();`, which this edit did not touch, so the '
            'fold must stay',
      );
      expect(controller.code.foldedBlocks, hasLength(1));

      controller.dispose();
    });

    test('Deleting a blank line further away', () {
      const example = 'a {\n  body();\n}\n\n\n\nb {\n  y();\n}\n';
      final controller = CodeController(text: example, language: java);
      controller.foldAt(0);

      controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 8,
      );
      controller.value = controller.value.replacedSelection('');

      expect(controller.text, 'a {}\nb {\n  y();\n}\n');
      expect(controller.code.hiddenRanges.ranges, hasLength(1));
      expect(controller.code.foldedBlocks, hasLength(1));

      controller.dispose();
    });

    test('The block is still unfoldable afterwards', () {
      const example = 'a {\n  body();\n}\n\n\n\nb {\n  y();\n}\n';
      final controller = CodeController(text: example, language: java);
      controller.foldAt(0);

      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 5,
      );
      controller.value = controller.value.replacedSelection('');

      controller.unfoldAt(0);

      expect(
        controller.text,
        'a {\n  body();\n}\n\n\nb {\n  y();\n}\n',
        reason: 'Unfolding reveals the hidden content that survived the edit',
      );

      controller.dispose();
    });

    test('But the hidden content changing still drops the fold', () {
      const example = 'a {\n  body();\n}\n\n\n\nb {\n  y();\n}\n';
      final controller = CodeController(text: example, language: java);
      controller.foldAt(0);

      controller.fullText = 'a {\n  other();\n}\n\n\n\nb {\n  y();\n}\n';

      expect(controller.code.foldedBlocks, isEmpty);
      expect(controller.code.hiddenRanges.ranges, isEmpty);

      controller.dispose();
    });
  });
}
