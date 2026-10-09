import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code/code_line.dart';

CodeLine _line(String text, {int start = 0}) =>
    CodeLine.fromTextAndStart(text, start);

void main() {
  group('CodeLine constructors', () {
    test('fromTextAndStart derives the range and the indent', () {
      final line = _line('  ab', start: 10);

      expect(line.text, '  ab');
      expect(line.textRange, const TextRange(start: 10, end: 14));
      expect(line.indent, 2);
    });

    test('fromTextAndRange derives the indent from the text', () {
      final line = CodeLine.fromTextAndRange(
        text: '\tab',
        textRange: const TextRange(start: 3, end: 6),
      );

      expect(line.indent, 1);
      expect(line.textRange, const TextRange(start: 3, end: 6));
    });

    test('indent counts leading spaces, tabs and newlines', () {
      expect(_line('\n\n\nx').indent, 3);
      expect(_line('   \t \nx').indent, 6);
      expect(_line('x  ').indent, 0);
      expect(_line('').indent, 0);
    });

    test('isReadOnly defaults to false and can be set', () {
      expect(_line('a').isReadOnly, isFalse);
      expect(
        CodeLine.fromTextAndStart('a', 0, isReadOnly: true).isReadOnly,
        isTrue,
      );
    });
  });

  group('CodeLine.copyWith', () {
    test('replaces only the given fields and keeps the range', () {
      final line = _line('  ab', start: 4);

      final copy = line.copyWith(text: 'cd');

      expect(copy.text, 'cd');
      // The range is NOT recalculated: copyWith is a partial override, so
      // an unchanged range survives a text change verbatim.
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

      expect(line.copyWith(isReadOnly: true).indent, 2);
      expect(
        line.copyWith(textRange: const TextRange(start: 9, end: 9)).indent,
        2,
      );
    });

    test('replaces isReadOnly', () {
      expect(_line('a').copyWith(isReadOnly: true).isReadOnly, isTrue);
    });
  });

  group('CodeLine equality', () {
    test('equal lines compare equal and hash equal', () {
      final a = _line('  ab', start: 2);
      final b = _line('  ab', start: 2);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differ by any of text, range or readOnly', () {
      final base = _line('  ab', start: 2);

      expect(base, isNot(_line('  ac', start: 2)));
      expect(base, isNot(_line('  ab', start: 3)));
      expect(
        base,
        isNot(CodeLine.fromTextAndStart('  ab', 2, isReadOnly: true)),
      );
    });

    test('differs from other types', () {
      expect(_line('a') == Object(), isFalse);
      // ignore: unrelated_type_equality_checks
      expect(_line('a') == 'a', isFalse);
    });
  });

  group('CodeLine.toString', () {
    test('reports readOnly, range and text', () {
      expect(
        _line('ab', start: 1).toString(),
        'CodeLine(ro: false, textRange: TextRange(start: 1, end: 3), '
        'text: "ab")',
      );
      expect(
        CodeLine.fromTextAndStart('ab', 1, isReadOnly: true).toString(),
        'CodeLine(ro: true, textRange: TextRange(start: 1, end: 3), '
        'text: "ab")',
      );
    });
  });
}
