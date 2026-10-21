import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import 'package:zuraffa_code_editor/src/code_field/re_editor_controller.dart';

void main() {
  testWidgets('a tap on the editor reaches the host', (tester) async {
    final controller = CodeController(text: 'abc');
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeFieldRe(controller: controller, onTap: () => taps++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getTopLeft(find.byType(CodeFieldRe)) + const Offset(5, 5),
    );
    await tester.pumpAndSettle();

    expect(taps, 1);

    controller.dispose();
  });

  testWidgets('the popup is rebuilt when the suggestions change', (
    tester,
  ) async {
    final controller = CodeController(text: 'abc');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeFieldRe(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    controller.popupController.show(['one']);
    await tester.pumpAndSettle();
    expect(controller.popupController.shouldShow, isTrue);

    // The popup is already up: the next change rebuilds it in place.
    controller.popupController.show(['two']);
    await tester.pumpAndSettle();
    expect(controller.popupController.shouldShow, isTrue);

    controller.popupController.hide();
    await tester.pumpAndSettle();
    expect(controller.popupController.shouldShow, isFalse);

    controller.dispose();
  });

  testWidgets('the tab key indents with the package\'s own semantics', (
    tester,
  ) async {
    final controller = CodeController(text: 'abc');
    final line = ReEditorCodeController(text: 'abc');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeFieldRe(
            controller: controller,
            lineController: line,
            focusNode: focusNode,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // The package's own action ran, so the tab is the package's indent and
    // not the editor's own.
    expect(controller.code.text, isNot('abc'));
    expect(controller.code.text.trim(), 'abc');

    controller.dispose();
    line.dispose();
    focusNode.dispose();
  });
}
