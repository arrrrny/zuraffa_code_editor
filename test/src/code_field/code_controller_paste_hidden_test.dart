import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import '../common/snippets.dart';

const String _pasted = '''
class MyClass {
\tvoid readOnlyMethod() {// [START section3]
\t}// [END section3]
\t// [START section4]
\tvoid method() {
\t}// [END section4]
}
''';

/// Simulates a paste: the framework rebuilds the *visible* text with the
/// inserted run and puts the caret at the end of that run.
TextEditingValue _paste(CodeController controller, String inserted) {
  final visible = controller.text;
  return TextEditingValue(
    text: '$visible$inserted',
    selection: TextSelection.collapsed(
      offset: visible.length + inserted.length,
    ),
  );
}

void main() {
  group('CodeController. Pasting text that introduces service comments', () {
    test('caret lands at the end of the pasted run', () {
      final controller = CodeController(
        text: '// [START section2]\nvoid method() {\n}\n',
        language: TwoMethodsSnippet.mode,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
      );

      controller.value = _paste(controller, _pasted);

      // The whole pasted run is longer than the resulting visible text, so
      // this is the `newValue.text.length > _code.visibleText.length` branch:
      // the framework's own caret must be kept.
      expect(
        controller.value.text.length,
        lessThan(_pasted.length),
        reason: 'sanity: the pasted service comments became hidden ranges',
      );
      expect(
        controller.selection.start,
        controller.value.text.length,
        reason: 'the caret belongs at the end of the pasted run',
      );
      expect(controller.selection.end, controller.selection.start);
    });

    test('caret lands after the pasted run when it is inserted mid-text', () {
      // A run that does NOT open a hidden range: nothing is swallowed, so the
      // only thing under test is that the caret follows the inserted run
      // instead of collapsing to the start of the changed block.
      const text = 'void method() {\n}\n';
      final controller = CodeController(
        text: text,
        language: TwoMethodsSnippet.mode,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
      );

      controller.value = TextEditingValue(
        text: 'int i = 1;\n${controller.text.substring(1)}',
        selection: const TextSelection.collapsed(offset: 11),
      );

      expect(controller.value.text, 'int i = 1;\noid method() {\n}\n');
      expect(controller.selection.start, 11);
    });

    test('the pasted text reaches fullText in full', () {
      final controller = CodeController(
        text: '// [START section2]\nvoid method() {\n}\n',
        language: TwoMethodsSnippet.mode,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
      );

      controller.value = _paste(controller, _pasted);

      // The editor replaces tabs with spaces on paste; only the tail is
      // stable enough to assert on.
      expect(controller.fullText, endsWith('  }// [END section4]\n}\n'));
      expect(controller.fullText.length, 183);
    });
  });
}
