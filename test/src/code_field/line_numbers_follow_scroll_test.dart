import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Upstream #259 / #19: scrolling the editor left the line numbers behind, and
/// the row that used to sit under the gutter escaped the widget entirely.
///
/// The gutter is handed its own controller from the same
/// `LinkedScrollControllerGroup` as the editor, so the two have to stay glued:
/// while the code scrolls down by any amount, the gutter scrolls by the same
/// amount and keeps showing the numbers of the lines that are on screen.
void main() {
  ScrollPosition editorPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  ScrollPosition gutterPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(GutterWidget),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  Future<CodeController> pumpManyLines(
    WidgetTester tester, {
    required int lines,
    bool wrap = false,
  }) async {
    final controller = CodeController(
      text: '${List.generate(lines, (i) => 'line $i').join('\n')}\n',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            width: 400,
            child: CodeField(controller: controller, wrap: wrap),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('the gutter keeps pace with the editor while dragging', (
    tester,
  ) async {
    await pumpManyLines(tester, lines: 60);

    expect(editorPosition(tester).pixels, 0);
    expect(gutterPosition(tester).pixels, 0);
    expect(
      editorPosition(tester).maxScrollExtent,
      greaterThan(220),
      reason: 'the fixture has to overflow the 220px viewport',
    );

    // Drag the editor, exactly as a user scrolls with the mouse or a finger.
    final gesture = await tester.startGesture(const Offset(300, 150));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final editor = editorPosition(tester);
    final gutter = gutterPosition(tester);

    expect(
      editor.pixels,
      greaterThan(50),
      reason: 'the drag must actually move the editor',
    );
    expect(
      gutter.pixels,
      closeTo(editor.pixels, 1),
      reason:
          'the line numbers have to scroll with the code, not stay at the top',
    );
    expect(
      gutter.pixels,
      lessThanOrEqualTo(gutter.maxScrollExtent),
      reason: 'the gutter must not scroll past its own content',
    );
  });

  testWidgets('the gutter follows a jump to the very bottom', (tester) async {
    await pumpManyLines(tester, lines: 60);

    editorPosition(tester).jumpTo(editorPosition(tester).maxScrollExtent);
    await tester.pumpAndSettle();

    final editor = editorPosition(tester);
    final gutter = gutterPosition(tester);

    expect(gutter.pixels, closeTo(editor.pixels, 1));
    expect(
      gutter.pixels,
      closeTo(gutter.maxScrollExtent, 1),
      reason: 'the last line number is on screen, none escaped the widget',
    );
  });

  testWidgets('the gutter also keeps pace when the field wraps', (
    tester,
  ) async {
    await pumpManyLines(tester, lines: 60, wrap: true);

    editorPosition(tester).jumpTo(editorPosition(tester).maxScrollExtent);
    await tester.pumpAndSettle();

    final editor = editorPosition(tester);
    final gutter = gutterPosition(tester);
    expect(gutter.pixels, closeTo(editor.pixels, 1));
  });
}
