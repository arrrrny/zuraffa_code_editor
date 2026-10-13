import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code/text_range.dart';

/// The `MyTextRange` extension is public API (`text_range.dart` is exported),
/// and `isAfter` lost its last in-package caller when the hidden-ranges assert
/// grew its own comparison. It stays, so it is covered here.
void main() {
  group('MyTextRange', () {
    test('isAfter is start-greater-or-equal for the other range', () {
      const after = TextRange(start: 10, end: 12);

      expect(after.isAfter(const TextRange(start: 0, end: 10)), isTrue);
      expect(after.isAfter(const TextRange(start: 9, end: 10)), isTrue);
      expect(after.isAfter(const TextRange(start: 11, end: 15)), isFalse);
      expect(after.isAfter(const TextRange(start: 10, end: 12)), isFalse);
    });

    test('normalized swaps a reversed range and keeps a normal one', () {
      const reversed = TextRange(start: 12, end: 10);
      expect(reversed.isNormalized, isFalse);
      expect(reversed.normalized.start, 10);
      expect(reversed.normalized.end, 12);

      const normal = TextRange(start: 10, end: 12);
      expect(normal.isNormalized, isTrue);
      expect(normal.normalized.start, 10);
      expect(normal.normalized.end, 12);
    });
  });
}
