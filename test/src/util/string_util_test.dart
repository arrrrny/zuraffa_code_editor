import 'package:flutter_test/flutter_test.dart';

import 'package:zuraffa_code_editor/src/util/string_util.dart';

void main() {
  group('StringUtil.isDigit', () {
    test('returns true for 0-9', () {
      for (final char in '0123456789'.split('')) {
        expect(StringUtil.isDigit(char), isTrue, reason: char);
      }
    });

    test('returns false for letters', () {
      expect(StringUtil.isDigit('a'), isFalse);
      expect(StringUtil.isDigit('Z'), isFalse);
    });

    test('returns false for non-ASCII digits', () {
      // Arabic-Indic digit zero. Not in the Unicode range we accept.
      expect(StringUtil.isDigit('\u0660'), isFalse);
    });

    test('returns false for empty and multi-char strings', () {
      expect(StringUtil.isDigit(''), isFalse);
      expect(StringUtil.isDigit('12'), isFalse);
    });
  });

  group('StringUtil.isLetterEng', () {
    test('returns true for a-z and A-Z', () {
      for (final char in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
        expect(StringUtil.isLetterEng(char), isTrue, reason: char);
      }
      for (final char in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        expect(StringUtil.isLetterEng(char), isTrue, reason: char);
      }
    });

    test('returns false for digits and punctuation', () {
      expect(StringUtil.isLetterEng('5'), isFalse);
      expect(StringUtil.isLetterEng('{'), isFalse);
    });

    test('returns false for non-ASCII letters', () {
      expect(StringUtil.isLetterEng('é'), isFalse);
      expect(StringUtil.isLetterEng('Д'), isFalse);
    });

    test('returns false for empty and multi-char strings', () {
      expect(StringUtil.isLetterEng(''), isFalse);
      expect(StringUtil.isLetterEng('ab'), isFalse);
    });
  });
}
