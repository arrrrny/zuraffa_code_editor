import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TabModifier', () {
    test('never rewrites the line it is handed', () {
      const modifier = TabModifier();

      // The modifier exists only as a marker that a tab has been typed; the
      // replacement itself happens in the controller, so `updateString` must
      // stay a no-op whatever it is given.
      expect(
        modifier.updateString(
          'void main() {}',
          const TextSelection.collapsed(offset: 0),
          const EditorParams(),
        ),
        isNull,
      );
      expect(
        modifier.updateString(
          '\tvoid main() {}',
          const TextSelection.collapsed(offset: 1),
          const EditorParams(),
        ),
        isNull,
      );
    });
  });
}
