import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import 'gutter_alignment_harness.dart';

/// Upstream #283 / #18: past ~1000 lines the editor "only shows blank lines".
///
/// The line-number column is a flex column that takes whatever the requested
/// [GutterStyle.width] leaves after the fixed issue/folding columns and the
/// margin to the code — 38 px at the defaults. That is enough for two digits,
/// not for three: the number then wraps, and a wrapped number is twice as tall
/// as the line it labels. Every row past the wrap is twice the pitch of the
/// code's line grid, so the gutter's scroll extent is double the code's, the
/// two views disagree about which rows are on screen, and the rows visible in
/// the code area have no number over them.
///
/// A number that does not fit is a font question, not a line-count one — the
/// test font advances a digit by 16 px, a real one by half that, so the wrap
/// lands on a different line count without changing the shape of the bug. The
/// tests below therefore assert the invariant rather than a line count: the
/// widest visible number renders on one line, every gutter row is exactly one
/// code line tall, and the gutter's scroll extent matches the code's.
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

  Future<CodeController> pumpLongFile(
    WidgetTester tester, {
    required int lines,
  }) async {
    final controller = CodeController(
      text: '${List.generate(lines, (i) => 'int value$i = $i;').join('\n')}\n',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 528,
            width: 400,
            child: CodeField(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  /// Every rendered line number, top to bottom, with its rendered size.
  List<Rect> numberBoxes(WidgetTester tester) => [
    for (final e in find.byType(Text).evaluate())
      if (RegExp(r'^\d+$').hasMatch((e.widget as Text).data ?? ''))
        tester.getRect(find.byWidget(e.widget as Text)),
  ];

  group('Gutter. Line-number column width (#18)', () {
    testWidgets('the widest visible number fits on one line', (wt) async {
      final controller = await pumpLongFile(wt, lines: 1200);
      final lineHeight = renderedLineHeight(wt, controller);
      expect(lineHeight, greaterThan(0));

      final boxes = numberBoxes(wt);
      expect(
        boxes.length,
        controller.code.hiddenLineRanges.visibleLineNumbers.length,
      );

      for (final box in boxes) {
        expect(
          box.height,
          closeTo(lineHeight, 0.001),
          reason:
              'a line number wrapped: the row is ${box.height} tall '
              'against a code line of $lineHeight',
        );
      }
    });

    testWidgets('the gutter table is one code line tall per visible row', (
      wt,
    ) async {
      final controller = await pumpLongFile(wt, lines: 1200);
      final lineHeight = renderedLineHeight(wt, controller);

      final table = find.descendant(
        of: find.byType(GutterWidget),
        matching: find.byType(Table),
      );
      final box = wt.renderObject<RenderBox>(table);

      final rows = controller.code.hiddenLineRanges.visibleLineNumbers.length;
      expect(box.size.height, closeTo(rows * lineHeight, 0.001));
    });

    testWidgets('the gutter scrolls as far as the code does', (wt) async {
      final controller = await pumpLongFile(wt, lines: 1200);
      final lineHeight = renderedLineHeight(wt, controller);
      expect(lineHeight, greaterThan(0));

      expect(
        gutterPosition(wt).maxScrollExtent,
        closeTo(editorPosition(wt).maxScrollExtent, 0.001),
        reason:
            'the gutter stops at a different place than the code, so '
            'scrolling to the bottom of the code shows rows that have no '
            'number over them',
      );
    });

    testWidgets('the gutter stays the requested width while numbers fit', (
      wt,
    ) async {
      await pumpLongFile(wt, lines: 40);

      final container = wt.renderObject<RenderBox>(
        find
            .descendant(
              of: find.byType(GutterWidget),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(container.size.width, closeTo(80.0, 0.001));

      final table = wt.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(GutterWidget),
          matching: find.byType(Table),
        ),
      );
      expect(
        table.size.width,
        closeTo(70.0, 0.001),
        reason:
            'the requested width must still be what renders once the '
            'numbers fit inside it',
      );
    });
  });
}
