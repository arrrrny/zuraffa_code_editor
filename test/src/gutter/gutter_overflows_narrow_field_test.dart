import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Upstream #259: "Line Numbers escape the widget", plus "why is the line
/// numbers side bar so... wide?".
///
/// The half of this report that is still live is not the one it names. The
/// report blames the gutter's own scroll controller; in this fork the gutter's
/// and the editor's controllers come off one `LinkedScrollControllerGroup`, and
/// that is pinned elsewhere ("the gutter scrolls as far as the code does").
///
/// What is still live is the layout. The gutter and the editor share a `Row`,
/// and the gutter was a plain child of it, so the row laid it out at its own
/// `style.width` — 80 px by default — whatever the field had to give:
///
/// - the `Row` overflows and the framework reports it, in a layout that is
///   entirely valid and needs no errors to be configured;
/// - the gutter's rendered rect runs past the field's own edge, which is the
///   "escape" in the title — the numbers genuinely paint outside the widget;
/// - the code area, the `Expanded` child, gets the leftover and is laid out
///   out of sight with it.
///
/// The fix bounds the gutter to the width the row has. Bounding rather than
/// giving it a flex share is load-bearing: a flex allocation is never handed
/// back when a child takes less than it, so a `Flexible` gutter would shrink
/// the code area by the gutter's slack at *every* field width. These tests pin
/// both halves of that trade — the gutter never escapes the field, and the code
/// area keeps every pixel the gutter is not using.
void main() {
  /// The code area's viewport.
  ///
  /// The scroll view the code actually lives in — not the `Scrollable` inside
  /// the `TextField`, which is the *content* of the horizontal scroller and is
  /// wider than the widget that clips it. Measured as the scroll view that
  /// stands between the field and its editor, which is the box the user sees
  /// and the one the horizontal scrollbar is pinned to.
  Rect codeArea(WidgetTester tester) => tester.getRect(
    find
        .ancestor(
          of: find.byType(TextField),
          matching: find.byType(SingleChildScrollView),
        )
        .first,
  );

  Future<CodeController> pumpField(
    WidgetTester tester, {
    required double width,
    GutterStyle gutterStyle = const GutterStyle(),
  }) async {
    final controller = CodeController(
      text:
          'int value1 = 1;\nint value2 = 2;\nint value3 = 3;\nint value4 = 4;\n',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 528,
            width: width,
            child: CodeField(
              renderer: CodeFieldRenderer.textField,
              controller: controller,
              gutterStyle: gutterStyle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  Rect fieldRect(WidgetTester tester) => tester.getRect(find.byType(CodeField));
  Rect gutterRect(WidgetTester tester) =>
      tester.getRect(find.byType(GutterWidget));

  /// Every rendered line number, with its rendered size.
  List<Rect> numberBoxes(WidgetTester tester) => [
    for (final w in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(GutterWidget),
        matching: find.byType(Text),
      ),
    ))
      if (RegExp(r'^\d+$').hasMatch(w.data ?? ''))
        tester.getRect(find.byWidget(w)),
  ];

  group('Gutter. Sharing the row with the code area (#259)', () {
    testWidgets('a field narrower than the gutter keeps the gutter inside it', (
      tester,
    ) async {
      // The default `GutterStyle.width` is 80 px and the row has 60 − 8 = 52
      // to give, so the gutter cannot have its full width. It used to keep it
      // anyway: 28 px of it outside the field, and an overflow from the
      // framework.
      await pumpField(tester, width: 60);

      final field = fieldRect(tester);
      final gutter = gutterRect(tester);

      expect(
        gutter.right,
        lessThanOrEqualTo(field.right),
        reason: 'the gutter renders past the right edge of the field',
      );
      expect(
        gutter.left,
        greaterThanOrEqualTo(field.left),
        reason: 'the gutter renders past the left edge of the field',
      );
      expect(
        gutter.width,
        lessThanOrEqualTo(field.width),
        reason: 'the gutter is wider than the field it belongs to',
      );
      expect(
        gutter.width,
        greaterThan(0),
        reason: 'the gutter collapsed to nothing instead of shrinking',
      );
    });

    testWidgets('the numbers still render, inside the field', (tester) async {
      await pumpField(tester, width: 60);

      final numbers = numberBoxes(tester);
      expect(numbers, isNotEmpty, reason: 'no line numbers rendered at all');

      final field = fieldRect(tester);
      for (final (i, box) in numbers.indexed) {
        expect(
          box.right,
          lessThanOrEqualTo(field.right),
          reason: 'line number ${i + 1} paints outside the field',
        );
        expect(
          box.left,
          greaterThanOrEqualTo(field.left),
          reason: 'line number ${i + 1} paints outside the field',
        );
      }
    });

    testWidgets('no width in the range overflows the row', (tester) async {
      // The assertion is the test: a row that cannot fit its children raises
      // the overflow in the framework, and an unhandled framework error fails
      // the test. Sweeping the range rather than one width keeps a fix that
      // only papers over the width it was written against from counting.
      for (final width in <double>[44, 60, 80, 100, 120, 150, 170, 200, 320]) {
        await pumpField(tester, width: width);
        expect(
          gutterRect(tester).right,
          lessThanOrEqualTo(fieldRect(tester).right),
          reason: 'at width $width the gutter escapes the field',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'at width $width the framework reported an error',
        );
      }
    });

    testWidgets('the code area keeps every pixel the gutter is not using', (
      tester,
    ) async {
      // The invariant that makes the bound the right instrument. A `Flexible`
      // gutter would pass every test above while quietly narrowing the code
      // area: a flex allocation is not handed back when a child takes less
      // than it, so at a 300 px field a `Flexible` gutter left the code 66 px
      // narrower — enough to break the horizontal scrollbar's "nothing to
      // scroll" case and the gutter-follows-editor drag test. The code area is
      // `Expanded`, so it must take exactly the width the gutter leaves.
      await pumpField(tester, width: 300);

      final field = fieldRect(tester);
      final gutter = gutterRect(tester);

      expect(gutter.width, closeTo(80.0, 0.001));
      expect(
        codeArea(tester).width,
        closeTo(field.width - 8 - gutter.width, 0.001),
        reason:
            'the code area must take exactly the width the gutter leaves, '
            'not a share of the row',
      );
    });

    testWidgets(
      'a field that can hold the gutter gets the width it asked for',
      (tester) async {
        // Bounding must not cost the gutter its width where there is room for
        // it: 400 − 8 leaves far more than the 80 px the default asks for.
        await pumpField(tester, width: 400);

        expect(gutterRect(tester).width, closeTo(80.0, 0.001));
      },
    );

    testWidgets('an oversized gutter is capped, not honoured past the field', (
      tester,
    ) async {
      // A host asking for more than the field has gets what the field has, not
      // an overflow. 200 px requested in a 60 px field is capped the same way
      // the default is.
      await pumpField(
        tester,
        width: 60,
        gutterStyle: const GutterStyle(width: 200),
      );

      final field = fieldRect(tester);
      final gutter = gutterRect(tester);

      expect(
        gutter.width,
        lessThanOrEqualTo(field.width),
        reason: 'the requested width overflowed the field',
      );
      expect(
        gutter.width,
        greaterThan(0),
        reason: 'the gutter collapsed instead of shrinking',
      );
    });

    testWidgets('an unbounded field is left exactly as it was', (tester) async {
      // The reporter's own workaround, and the shape many hosts use: the field
      // inside a scroll view, where the row is wide already. Nothing to bound,
      // so the gutter keeps its full requested width and the code keeps all
      // the rest.
      final controller = CodeController(
        text: 'int value1 = 1;\nint value2 = 2;\n',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 600,
                child: CodeField(
                  renderer: CodeFieldRenderer.textField,
                  controller: controller,
                  gutterStyle: const GutterStyle(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(gutterRect(tester).width, closeTo(80.0, 0.001));
    });
  });
}
