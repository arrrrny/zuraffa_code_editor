import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  testWidgets('Page Up / Page Down scroll the editor by one viewport', (
    tester,
  ) async {
    final controller = CodeController(
      text: '${List.generate(40, (i) => 'line $i').join('\n')}\n',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 400,
            child: CodeField(controller: controller),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    final vertical = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(EditableText),
        matching: find.byType(Scrollable),
      ),
    );
    expect(vertical.position.pixels, 0);
    expect(
      vertical.position.maxScrollExtent,
      greaterThan(200),
      reason: 'the fixture must actually overflow the 200px viewport',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(
      vertical.position.pixels,
      closeTo(200, 1),
      reason: 'Page Down must scroll the editor one viewport',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(
      vertical.position.pixels,
      closeTo(0, 1),
      reason: 'Page Up must scroll the editor back one viewport',
    );

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });
}
