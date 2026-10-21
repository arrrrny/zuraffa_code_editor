import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import 'package:zuraffa_code_editor/src/code_field/re_editor_controller.dart';

import '../common/snippets.dart';

/// re_editor only installs its own shortcut handling — and with it the
/// package's overriding actions — on the desktop platforms. On Android and
/// iOS it handles the keys itself, in the editor's own focus node.
///
/// The test environment reports Android as its platform, so the override is
/// set to a desktop one here, before anything reads it: re_editor caches
/// `kIsAndroid` in a lazily initialized `final`.
void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('the tab key runs the package\'s own action', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
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
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // The package's own tab action inserts a whole indent, where the
    // editor's own tab action would indent to the next tab stop — one
    // space at this column.
    expect(controller.code.text, 'abc  ');

    controller.dispose();
    line.dispose();
    focusNode.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the enter key runs the package\'s own action', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
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
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();

    // The popup is up, so the package's own enter action commits the
    // suggestion instead of breaking the line.
    controller.popupController.show(['alpha']);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.code.text, 'alpha ');

    controller.dispose();
    line.dispose();
    focusNode.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  group('the clipboard', () {
    /// The calls the platform channel has seen.
    late List<MethodCall> calls;

    /// The text the last copy put on the clipboard.
    String clipboardText() {
      final copies = calls.where((c) => c.method == 'Clipboard.setData');
      expect(copies.length, 1, reason: 'one copy');
      return (copies.first.arguments as Map)['text'] as String;
    }

    setUp(() {
      calls = <MethodCall>[];
    });

    /// A field with a folded document and everything selected.
    Future<CodeController> pumpFolded(WidgetTester tester) async {
      final controller = CodeController(
        text: MethodSnippet.full,
        language: java,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
      );
      final line = ReEditorCodeController(text: MethodSnippet.full);
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(line.dispose);
      addTearDown(focusNode.dispose);

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

      controller.foldAt(1);
      await tester.pumpAndSettle();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tester.pumpAndSettle();

      return controller;
    }

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });

    testWidgets('the copy takes the hidden lines with it', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = await pumpFolded(tester);
      final full = controller.code.text;
      // The fold really hides something, or the copy would prove nothing.
      expect(full, isNot(controller.text));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      // The copy is the package's, not the editor's: the lines the fold
      // hides are on the clipboard with the rest of the document.
      expect(clipboardText(), full);
      // The copy leaves the document alone.
      expect(controller.code.text, full);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('the cut takes the hidden lines with it', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = await pumpFolded(tester);
      final full = controller.code.text;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      // The cut starts the controller's analysis, which is debounced.
      await tester.pump(const Duration(milliseconds: 600));

      // What was cut is the document, the hidden lines included.
      expect(clipboardText(), full);
      expect(controller.code.text, isNot(full));

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
