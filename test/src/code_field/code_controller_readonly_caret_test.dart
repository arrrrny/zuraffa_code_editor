import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import '../common/create_app.dart';

/// A refused edit must leave the caret exactly where it was.
///
/// The read-only gate lives in `set value` → `_getEditResultNotBreakingReadOnly`
/// and refuses the *text* write. The caret is a separate write, so an edit that
/// replaces text and then moves the selection has to check that the text write
/// actually landed — otherwise a refused `Enter` advances the caret one offset
/// into the read-only region (#147).
///
/// The document is the upstream read-only fixture. A `ro//readonly` comment
/// makes the line it starts on, and every line below it, read-only, and the
/// comment itself is a hidden range — so the visible text is
/// `'\nabc\nro\nro\nabc\n'`, with the read-only region starting at offset 5
/// (the first visible character after the second newline).
const _readonlyBeginning = '\nabc\nro//readonly\nro//readonly\nabc\n';

/// The visible text the fixture above renders.
const _visible = '\nabc\nro\nro\nabc\n';

/// The document above pumped with `createApp`, which disposes the controller
/// with the widget tree — so the test must not dispose it a second time.
Future<CodeController> _pump(WidgetTester wt) async {
  final controller = CodeController(text: _readonlyBeginning, language: java);
  final focusNode = FocusNode();

  await wt.pumpWidget(createApp(controller, focusNode));
  focusNode.requestFocus();

  return controller;
}

void main() {
  group('A refused edit leaves the caret put', () {
    testWidgets('insertStr at a read-only position', (WidgetTester wt) async {
      final controller = await _pump(wt);

      controller.setCursor(5); // the first read-only character
      final before = controller.selection;

      controller.insertStr('X');

      expect(controller.text, _visible);
      expect(controller.selection, before);
    });

    testWidgets('removeChar at a read-only position', (WidgetTester wt) async {
      final controller = await _pump(wt);

      // Deleting the newline that ends the editable line would pull the
      // read-only line up into it.
      controller.setCursor(5);
      final before = controller.selection;

      controller.removeChar();

      expect(controller.text, _visible);
      expect(controller.selection, before);
    });

    testWidgets('removeSelection across a read-only position', (
      WidgetTester wt,
    ) async {
      final controller = await _pump(wt);

      // The start of the read-only region through to the line below it.
      controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 8,
      );
      final before = controller.selection;

      controller.removeSelection();

      expect(controller.text, _visible);
      expect(controller.selection, before);
    });

    testWidgets('Enter at a read-only position, through the real key path', (
      WidgetTester wt,
    ) async {
      final controller = await _pump(wt);

      controller.setCursor(5); // the first read-only character
      final before = controller.selection;

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(controller.text, _visible);
      expect(controller.selection, before);
    });

    testWidgets('Enter anywhere in the read-only region keeps the caret', (
      WidgetTester wt,
    ) async {
      final controller = await _pump(wt);

      // Every offset of the read-only region, driven by the real key path.
      for (final offset in [5, 6, 8]) {
        controller.setCursor(offset);
        final before = controller.selection;

        await wt.sendKeyEvent(LogicalKeyboardKey.enter);

        expect(
          controller.text,
          _visible,
          reason: 'Enter at $offset must not break the read-only region',
        );
        expect(
          controller.selection,
          before,
          reason: 'Enter at $offset must not move the caret',
        );
      }
    });

    testWidgets('Enter at the boundary before the read-only region', (
      WidgetTester wt,
    ) async {
      final controller = await _pump(wt);

      // Right before the first read-only character: the gate refuses this too,
      // because the newline it would insert ends the read-only region.
      controller.setCursor(4);
      final before = controller.selection;

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(controller.text, _visible);
      expect(controller.selection, before);
    });
  });

  group('An accepted edit still moves the caret', () {
    testWidgets('insertStr at an editable position', (WidgetTester wt) async {
      final controller = CodeController(
        text: _readonlyBeginning,
        language: java,
      );
      addTearDown(controller.dispose);
      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              renderer: CodeFieldRenderer.textField,
              controller: controller,
            ),
          ),
        ),
      );

      // The trailing editable line: nothing here is read-only.
      controller.setCursor(14);
      controller.insertStr('d');

      expect(controller.text, '\nabc\nro\nro\nabcd\n');
      expect(controller.selection, const TextSelection.collapsed(offset: 15));

      // The analysis debounce is a 500 ms timer on the controller.
      controller.dismiss();
      await wt.pump(const Duration(seconds: 10));
    });

    testWidgets('removeSelection inside the editable region', (
      WidgetTester wt,
    ) async {
      final controller = CodeController(
        text: _readonlyBeginning,
        language: java,
      );
      addTearDown(controller.dispose);
      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              renderer: CodeFieldRenderer.textField,
              controller: controller,
            ),
          ),
        ),
      );

      // 'abc' on the trailing editable line.
      controller.selection = const TextSelection(
        baseOffset: 11,
        extentOffset: 14,
      );

      controller.removeSelection();

      expect(controller.text, '\nabc\nro\nro\n\n');
      expect(controller.selection, const TextSelection.collapsed(offset: 11));

      // The analysis debounce is a 500 ms timer on the controller.
      controller.dismiss();
      await wt.pump(const Duration(seconds: 10));
    });
  });
}
