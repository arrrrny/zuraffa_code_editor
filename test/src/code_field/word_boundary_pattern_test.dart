import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code/reg_exp.dart';
import 'package:zuraffa_code_editor/src/code_field/text_editing_value.dart';

void main() {
  // A RegExp handed to the engine (indexOf / lastIndexOf / split) must not be
  // a shared instance: on the web target dart2js can carry `lastIndex` state
  // between calls on a reused RegExp, which upstream corrupted editing state
  // with (akvelon/flutter-code-editor#61). The word-boundary scan therefore
  // goes through wordSplitPatternForScan() instead of handing RegExps.wordSplit
  // to the engine directly. (On the VM Dart caches RegExp objects by pattern,
  // so the hazard and the seam are both invisible here — the VM-side pin is
  // the seam's contract plus deterministic results.)
  group('word boundary scanning', () {
    test('the scan pattern matches RegExps.wordSplit', () {
      expect(wordSplitPatternForScan().pattern, RegExps.wordSplit.pattern);
    });

    test('repeated word lookups on one value stay deterministic', () {
      final value = TextEditingValue(
        text: 'final foo = bar_baz;',
        selection: const TextSelection.collapsed(offset: 8),
      );

      final firstStart = value.wordAtCursorStart;
      final firstWord = value.wordAtCursor;
      final firstToCursor = value.wordToCursor;
      final secondStart = value.wordAtCursorStart;
      final secondWord = value.wordAtCursor;
      final secondToCursor = value.wordToCursor;

      expect(firstStart, secondStart);
      expect(firstWord, secondWord);
      expect(firstToCursor, secondToCursor);
      expect(firstWord, 'foo');
      expect(firstToCursor, 'fo');
    });

    test('cursors inside and between words resolve correctly', () {
      TextEditingValue valueAt(int offset) => TextEditingValue(
        text: 'aa bb\ncc_dd ee',
        selection: TextSelection.collapsed(offset: offset),
      );

      expect(valueAt(0).wordAtCursor, 'aa');
      expect(valueAt(1).wordAtCursor, 'aa');
      expect(valueAt(4).wordAtCursor, 'bb');
      expect(valueAt(6).wordAtCursor, 'cc_dd');
      expect(valueAt(9).wordAtCursor, 'cc_dd');
      expect(valueAt(12).wordAtCursor, 'ee');
      expect(valueAt(13).wordAtCursor, 'ee');
    });
  });
}
