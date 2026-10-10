import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeController.outdentSelection', () {
    test('a line shorter than one tab loses its indent entirely', () {
      // `tabSpaces` is pinned to 4, so `  x;` (4 characters, 2 of them
      // indentation) has no full tab to remove — it falls back to trimming
      // whatever indentation it does have.
      const snippet = 'void main() {\n  x;\n}';
      final controller = CodeController(
        text: snippet,
        params: const EditorParams(tabSpaces: 4),
      );
      controller.value = const TextEditingValue(
        text: snippet,
        selection: TextSelection(baseOffset: 0, extentOffset: snippet.length),
      );

      controller.outdentSelection();

      expect(controller.text, 'void main() {\nx;\n}');
    });

    test('a line shorter than one tab and not indented is left alone', () {
      const snippet = 'void main() {\nx;\n}';
      final controller = CodeController(text: snippet);
      controller.value = const TextEditingValue(
        text: snippet,
        selection: TextSelection(baseOffset: 0, extentOffset: snippet.length),
      );

      controller.outdentSelection();

      expect(controller.text, snippet);
    });
  });

  group('Code.getEditResult', () {
    test('an edit that does not change the visible text reports no change', () {
      const text = 'void main() {}';
      final code = Code(text: text);

      final result = code.getEditResult(
        const TextSelection.collapsed(offset: text.length),
        const TextEditingValue(text: text),
      );

      // Both diffs come back empty, so the full text survives untouched and no
      // line range is attributed to the edit.
      expect(result.fullTextAfter, text);
      expect(result.linesChanged, TextRange.empty);
    });
  });
}
