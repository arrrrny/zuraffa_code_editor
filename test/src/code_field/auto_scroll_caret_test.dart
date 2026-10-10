import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  testWidgets('vertical scroll follows the caret while typing', (tester) async {
    final controller = CodeController(text: '');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 200, child: CodeField(controller: controller)),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      List.generate(40, (i) => 'line $i').join('\n'),
    );
    await tester.pumpAndSettle();

    final vertical = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(EditableText),
        matching: find.byType(Scrollable),
      ),
    );

    expect(
      vertical.position.pixels,
      greaterThan(0),
      reason:
          'typing past the bottom of the viewport should scroll the caret '
          'into view',
    );

    // Stop the caret blink timer so the binding does not see it pending.
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });
}
