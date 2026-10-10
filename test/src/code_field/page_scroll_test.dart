import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
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
    ScrollPosition gutterPosition() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(GutterWidget),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    expect(vertical.position.pixels, 0);
    expect(
      vertical.position.maxScrollExtent,
      greaterThan(200),
      reason: 'the fixture must actually overflow the 200px viewport',
    );

    // One page is the text viewport — the editor box minus the
    // InputDecorator's vertical padding — not the box height.
    final page = vertical.position.viewportDimension;

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(
      vertical.position.pixels,
      closeTo(page, 1),
      reason: 'Page Down must scroll the editor one viewport',
    );
    expect(
      gutterPosition().pixels,
      closeTo(page, 1),
      reason: 'the gutter must follow the editor (LinkedScrollControllerGroup)',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(
      vertical.position.pixels,
      closeTo(0, 1),
      reason: 'Page Up must scroll the editor back one viewport',
    );

    // Pressing past the end must clamp at the max extent.
    for (var i = 0; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
    }
    expect(
      vertical.position.pixels,
      closeTo(vertical.position.maxScrollExtent, 0.01),
      reason: 'Page Down past the end must clamp at the max extent',
    );
    expect(
      gutterPosition().pixels,
      closeTo(vertical.position.pixels, 0.01),
      reason: 'the gutter must follow the editor to the clamped extent',
    );

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });
}
