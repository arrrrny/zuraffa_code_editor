// ignore_for_file: discarded_futures

import 'package:zuraffa_code_editor/src/code_field/code_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/python.dart';

void main() {
  group('CodeController.languageId', () {
    test('is empty until a language is set', () {
      final controller = CodeController(text: 'int a;');
      addTearDown(controller.dispose);

      expect(controller.languageId, '');
    });

    test('takes the language hashCode once a language is registered', () {
      final controller = CodeController(text: 'int a;', language: java);
      addTearDown(controller.dispose);

      expect(controller.languageId, java.hashCode.toString());
    });

    test('changes when the language changes', () {
      final controller = CodeController(text: 'int a;', language: java);
      addTearDown(controller.dispose);

      controller.language = python;

      expect(controller.languageId, python.hashCode.toString());
    });
  });

  group('CodeController.visibleSectionNames', () {
    test('starts empty', () {
      final controller = CodeController(text: 'int a;');
      addTearDown(controller.dispose);

      expect(controller.visibleSectionNames, isEmpty);
    });

    test('round-trips the names through the setter', () {
      final controller = CodeController(
        text: 'int a;',
        visibleSectionNames: const {'method'},
      );
      addTearDown(controller.dispose);

      expect(controller.visibleSectionNames, {'method'});

      controller.visibleSectionNames = {'other'};
      expect(controller.visibleSectionNames, {'other'});

      controller.visibleSectionNames = {};
      expect(controller.visibleSectionNames, isEmpty);
    });
  });
}
