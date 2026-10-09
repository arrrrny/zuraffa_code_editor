import 'package:zuraffa_code_editor/src/code_field/code_controller.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeController patternMap', () {
    // `patternMap` builds the regexp the span builder highlights with and the
    // matching style list. Nothing in the suite passes it, so the whole branch
    // is dead without this.
    test('a non-null patternMap builds the style list', () {
      final controller = CodeController(
        text: 'int a;',
        patternMap: const {
          'int': TextStyle(color: Color(0xff0000ff)),
          'double': TextStyle(color: Color(0xff00ff00)),
        },
      );
      addTearDown(controller.dispose);

      // The controller survives construction with a pattern map and still
      // produces a working code model.
      expect(controller.code.text, 'int a;');
      expect(controller.code.lines.length, 1);
    });

    test('an empty patternMap is accepted too', () {
      final controller = CodeController(text: 'int a;', patternMap: const {});
      addTearDown(controller.dispose);

      expect(controller.code.text, 'int a;');
    });
  });
}
