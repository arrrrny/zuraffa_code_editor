import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code_modifiers/close_block_code_modifier.dart';
import 'package:zuraffa_code_editor/src/code_field/editor_params.dart';

void main() {
  const modifier = CloseBlockModifier();
  const params = EditorParams(tabSpaces: 2);

  // The modifier runs when a closing brace is typed: `text` does not yet
  // contain the brace, and `sel` is the cursor where it will be inserted.
  TextEditingValue? apply(String text, int offset) {
    return modifier.updateString(
      text,
      TextSelection.collapsed(offset: offset),
      params,
    );
  }

  group('CloseBlockModifier', () {
    test('is registered on the closing brace character', () {
      expect(modifier.char, '}');
    });

    test('removes exactly tabSpaces spaces before an empty line', () {
      final result = apply('  {\n    x;\n  ', 13);

      expect(result!.text, '  {\n    x;\n}');
      expect(result.selection.baseOffset, 12);
    });

    test('returns null with fewer than tabSpaces spaces', () {
      // One space before the cursor, not two.
      final result = apply('  {\n x;\n ', 10);

      expect(result, isNull);
    });

    test('returns null when a newline precedes the spaces', () {
      final result = apply('a\n', 2);

      expect(result, isNull);
    });

    test('returns null when a non-space character precedes the spaces', () {
      // The scanner walks back over two spaces, hits 'x' and resets the count.
      final result = apply('x  ', 3);

      expect(result, isNull);
    });
  });
}
