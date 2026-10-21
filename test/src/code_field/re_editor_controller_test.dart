import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code_field/re_editor_controller.dart';

void main() {
  group('ReEditorCodeController', () {
    test('exposes the text it was built with', () {
      final controller = ReEditorCodeController(text: 'abc\ndef');
      expect(controller.text, 'abc\ndef');
      controller.dispose();
    });

    test('text setter replaces the content', () {
      final controller = ReEditorCodeController(text: 'abc');
      controller.text = 'one\ntwo';
      expect(controller.text, 'one\ntwo');
      controller.dispose();
    });

    test('selection setter and getter round-trip global offsets', () {
      final controller = ReEditorCodeController(text: 'abc\ndef\nghi');
      controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      final selection = controller.selection;
      expect(selection.baseOffset, 5);
      expect(selection.extentOffset, 9);
      controller.dispose();
    });

    test('notifies listeners when the content changes', () {
      final controller = ReEditorCodeController(text: 'abc');
      var notified = 0;
      controller.addListener(() => notified++);
      controller.text = 'abcd';
      expect(notified, greaterThan(0));
      controller.dispose();
    });
  });
}
