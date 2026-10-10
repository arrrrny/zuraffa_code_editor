import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/code_field/text_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextSelectionExtension', () {
    test('length is the distance between the two offsets', () {
      const selection = TextSelection(baseOffset: 5, extentOffset: 12);

      expect(selection.length, 7);
    });

    test('length is the distance regardless of direction', () {
      const forward = TextSelection(baseOffset: 5, extentOffset: 12);
      const backward = TextSelection(baseOffset: 12, extentOffset: 5);

      // `start`/`end` are normalised first, so both directions agree.
      expect(forward.length, 7);
      expect(backward.length, 7);
    });

    test('length is zero for a collapsed selection', () {
      const selection = TextSelection.collapsed(offset: 9);

      expect(selection.length, 0);
    });
  });
}
