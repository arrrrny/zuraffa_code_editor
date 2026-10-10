// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_final_locals

import 'package:zuraffa_code_editor/src/code_field/code_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeController.outdentSelection', () {
    // The `line == '\n'` and `line.length < tabSpaces` guards inside the
    // `modifySelectedLines` callback are only reachable with a selection that
    // actually spans a short or blank line.
    test('a blank line in the selection is left alone', () {
      // `CodeLines` keeps the trailing newline on each line, so the lines are
      // "aaaa\n", "\n", "aaaa\n"; the middle one is the blank line the
      // `line == '\n'` guard short-circuits on.
      final controller = CodeController(text: 'aaaa\n\naaaa\n');
      addTearDown(controller.dispose);

      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 11,
      );
      controller.outdentSelection();

      expect(controller.text, 'aaaa\n\naaaa\n');
    });

    test('a line shorter than the tab width loses its indentation', () {
      final controller = CodeController(
        text:
            'a\n'
            '  b\n',
      );
      addTearDown(controller.dispose);

      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );

      controller.outdentSelection();

      expect(controller.text, 'a\nb\n');
    });
  });
}
