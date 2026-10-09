import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/python.dart';
import 'package:zuraffa_code_editor/src/code/code.dart';
import 'package:zuraffa_code_editor/src/code/code_line.dart';
import 'package:zuraffa_code_editor/src/named_sections/parsers/brackets_start_end.dart';

CodeLine _line(String text, {int start = 0}) =>
    CodeLine.fromTextAndStart(text, start);

void main() {
  group('CodeLine.copyWith', () {
    test('replaces only the given fields, keeping the range as-is', () {
      final line = CodeLine.fromTextAndRange(
        text: '  ab',
        textRange: const TextRange(start: 4, end: 8),
      );

      final copy = line.copyWith(text: 'cd');

      expect(copy.text, 'cd');
      expect(copy.textRange, const TextRange(start: 4, end: 8));
      expect(copy.isReadOnly, isFalse);
    });

    test('recalculates the indent when text changes', () {
      final line = _line('ab');

      expect(line.copyWith(text: '    cd').indent, 4);
      expect(line.indent, 0);
    });

    test('keeps the existing indent when text is not replaced', () {
      final line = _line('  ab');

      final copy = line.copyWith(isReadOnly: true);

      expect(copy.isReadOnly, isTrue);
      expect(copy.indent, line.indent);
    });

    test('replaces isReadOnly', () {
      expect(_line('a').copyWith(isReadOnly: true).isReadOnly, isTrue);
    });
  });

  group('Read-only sections keep their indentation', () {
    test('a read-only line inside a named section keeps its indent', () {
      final code = Code(
        text: '''
def outer():
    def inner():
        pass
    # [START locked]
    def locked():
        pass
    # [END locked]
''',
        language: python,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
        readOnlySectionNames: const {'locked'},
      );

      final lines = code.lines.lines;
      final lockedLine = lines.firstWhere(
        (l) => l.isReadOnly && l.text.contains('def locked():'),
      );

      expect(lockedLine.text.trim(), 'def locked():');
      expect(lockedLine.indent, 4);
    });

    test('a control: indentation of an unmarked code', () {
      final code = Code(
        text: '''
def outer():
    def inner():
        pass
''',
        language: python,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
        readOnlySectionNames: const {},
      );

      final indented = code.lines.lines
          .where((l) => l.text.trim().isNotEmpty)
          .map((l) => l.indent)
          .toList();

      expect(indented, equals([0, 4, 8]));
    });
  });
}
