import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  group('GutterStyle.padding', () {
    test('defaults to zero so existing layouts are unchanged', () {
      expect(const GutterStyle().padding, EdgeInsets.zero);
      expect(GutterStyle.none.padding, EdgeInsets.zero);
    });

    test('is carried through copyWith', () {
      const style = GutterStyle(padding: EdgeInsets.only(left: 4));
      expect(
        style.copyWith(textStyle: const TextStyle()).padding,
        const EdgeInsets.only(left: 4),
      );
      // copyWith without the argument keeps the current value.
      expect(style.copyWith().padding, const EdgeInsets.only(left: 4));
    });
  });

  testWidgets('gutter padding shifts the numbers without moving the grid', (
    tester,
  ) async {
    Future<Offset> pumpAndGetNumberOffset(EdgeInsets padding) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = CodeController(
        text: '${List.generate(10, (i) => 'line $i').join('\n')}\n',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              controller: controller,
              gutterStyle: GutterStyle(padding: padding),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getTopLeft(find.text('1'));
    }

    final base = await pumpAndGetNumberOffset(EdgeInsets.zero);
    final dy = tester.getTopLeft(find.text('2')).dy - base.dy;

    final padded = await pumpAndGetNumberOffset(
      const EdgeInsets.only(left: 4, top: 2),
    );
    final paddedDy = tester.getTopLeft(find.text('2')).dy - padded.dy;

    expect(
      padded.dx - base.dx,
      4,
      reason: 'left padding must inset the whole gutter column',
    );
    expect(
      padded.dy - base.dy,
      2,
      reason: 'top padding must inset the whole gutter column',
    );
    expect(paddedDy, dy, reason: 'row pitch must not change');
  });
}
