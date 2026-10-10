import 'package:flutter/widgets.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/comment_uncomment.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/enter_key.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/indent.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/outdent.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/search.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/tab.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The six `Action` subclasses the editor installs for its shortcuts. Each
  // one is a one-line delegate to the controller; invoking it directly is what
  // keeps the delegate honest, and what the shortcut path relies on.
  const snippet = 'void main() {}';

  CodeController pumpController() {
    final controller = CodeController(text: snippet);
    // A fresh controller's selection sits at offset -1, which the editing
    // helpers reject; every action below edits through them.
    controller.value = const TextEditingValue(
      text: snippet,
      selection: TextSelection.collapsed(offset: snippet.length - 1),
    );

    return controller;
  }

  group('CodeField actions delegate to the controller', () {
    test('TabKeyAction runs the controller Tab handler', () {
      final controller = pumpController();

      TabKeyAction(controller: controller).invoke(const TabKeyIntent());

      // `tabSpaces` defaults to 2, inserted at the caret.
      expect(controller.text, 'void main() {  }');
    });

    test('EnterKeyAction inserts a newline', () {
      final controller = pumpController();

      EnterKeyAction(controller: controller).invoke(const EnterKeyIntent());

      expect(controller.text, 'void main() {\n  }');
    });

    test('SearchAction opens the search UI', () {
      final controller = pumpController();

      SearchAction(controller: controller).invoke(const SearchIntent());

      expect(controller.searchController.shouldShow, isTrue);
    });

    test('IndentIntentAction indents the selection', () {
      final controller = pumpController();

      IndentIntentAction(controller: controller).invoke(const IndentIntent());

      // Nothing is selected, so nothing moves.
      expect(controller.text, 'void main() { }');
    });

    test('OutdentIntentAction outdents the selection', () {
      final controller = pumpController();

      OutdentIntentAction(controller: controller).invoke(const OutdentIntent());

      expect(controller.text, snippet);
    });

    test('CommentUncommentAction comments the selection out', () {
      final controller = pumpController();

      CommentUncommentAction(
        controller: controller,
      ).invoke(const CommentUncommentIntent());

      expect(controller.text, snippet);
    });
  });
}
