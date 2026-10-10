import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web workarounds', () {
    test('disabling the built-in search is a no-op off the web', () {
      // On the test platform the stub implementation is compiled in, so the
      // call must succeed without touching the DOM. On the web the real
      // implementation runs the same entry point.
      expect(disableBuiltInSearchIfWeb, returnsNormally);
    });
  });
}
