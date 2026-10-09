import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code/code.dart';
import 'package:zuraffa_code_editor/src/named_sections/parsers/brackets_start_end.dart';

import '../common/snippets.dart';

Code _codeWithReadOnlySection() => Code(
  text: TwoMethodsSnippet.full,
  language: TwoMethodsSnippet.mode,
  namedSectionParser: const BracketsStartEndNamedSectionParser(),
  readOnlySectionNames: const {'section1'},
);

void main() {
  group('Code.isReadOnlySelected', () {
    test('an empty selection (-1..-1) is not read-only', () {
      final code = _codeWithReadOnlySection();

      expect(
        code.isReadOnlySelected(const TextRange(start: -1, end: -1)),
        isFalse,
      );
    });

    test('a selection inside a read-only section is read-only', () {
      final code = _codeWithReadOnlySection();

      final readOnlyLine = code.lines.lines.firstWhere((l) => l.isReadOnly);
      final range = readOnlyLine.textRange;

      expect(code.isReadOnlySelected(range), isTrue);
    });

    test(
      'a selection spanning a read-only and an editable line is read-only',
      () {
        final code = _codeWithReadOnlySection();

        final lines = code.lines.lines;
        final readOnlyIndex = lines.indexWhere((l) => l.isReadOnly);
        expect(readOnlyIndex, greaterThanOrEqualTo(0));
        // Span the last read-only line and one line after it.
        final end = lines[readOnlyIndex + 1].textRange.end;

        expect(code.isReadOnlySelected(TextRange(start: 0, end: end)), isTrue);
      },
    );

    test('a collapsed selection at a read-only boundary is read-only', () {
      final code = _codeWithReadOnlySection();

      final readOnlyLine = code.lines.lines.firstWhere((l) => l.isReadOnly);

      // The normalized-collapsed branch is what a single caret uses.
      expect(
        code.isReadOnlySelected(readOnlyLine.textRange),
        isTrue,
        reason: 'a collapsed range inside the read-only section counts',
      );
    });

    test('with no read-only sections nothing is read-only', () {
      final code = Code(
        text: TwoMethodsSnippet.full,
        language: TwoMethodsSnippet.mode,
      );

      expect(
        code.isReadOnlySelected(
          const TextRange(start: 0, end: TwoMethodsSnippet.full.length),
        ),
        isFalse,
      );
    });
  });
}
