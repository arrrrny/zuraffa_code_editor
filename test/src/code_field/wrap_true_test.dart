import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// The editor's own render box — the `TextField` inside `CodeField`.
Size _editorSize(WidgetTester tester) => tester.getSize(find.byType(TextField));

Future<void> _pumpLongLine(WidgetTester tester, {required bool wrap}) async {
  final controller = CodeController(text: '');
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 300,
          child: CodeField(
            controller: controller,
            wrap: wrap,
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byType(TextField));
  await tester.pump();

  await tester.enterText(find.byType(TextField), 'x' * 200);
  await tester.pumpAndSettle();

  // The caret blink timer must not outlive the test binding.
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

/// Pumps a `CodeField` holding long lines in a deliberately narrow editor,
/// where a couple of lines land exactly on a wrap boundary.
Future<void> _pumpNarrowWrappedText(WidgetTester tester) async {
  final controller = CodeController(
    text: List.generate(40, (i) => 'line $i ${'y' * 100}').join('\n'),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 300,
          child: CodeField(
            controller: controller,
            wrap: true,
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The content height behind the gutte's own scroll view: how many pixels of
/// rows it has, so it can be compared with the editor's.
double _contentHeight(ScrollableState scrollable) =>
    scrollable.position.maxScrollExtent + scrollable.position.viewportDimension;

ScrollableState _editorScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(EditableText),
        matching: find.byType(Scrollable),
      ),
    );

ScrollableState _gutterScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(GutterWidget),
        matching: find.byType(Scrollable),
      ),
    );

void main() {
  group('CodeField wrap', () {
    testWidgets(
      'wrap: false lays the line out horizontally (a regression pin)',
      (tester) async {
        await _pumpLongLine(tester, wrap: false);

        expect(
          _editorSize(tester).width,
          greaterThan(200),
          reason:
              'without wrapping the field must grow past its viewport so it '
              'scrolls horizontally',
        );
        expect(
          _editorSize(tester).height,
          lessThan(60),
          reason: 'an unwrapped line still occupies a single visual row',
        );
      },
    );

    testWidgets('wrap: true soft-wraps the long line into the viewport', (
      tester,
    ) async {
      await _pumpLongLine(tester, wrap: true);

      expect(
        _editorSize(tester).width,
        lessThanOrEqualTo(200),
        reason:
            'with wrapping the field must not grow past its viewport; the '
            'line must reflow instead',
      );
      expect(
        _editorSize(tester).height,
        greaterThan(100),
        reason: '200 characters cannot fit one visual row of a 200px box',
      );
    });

    testWidgets('the gutter scrolls in lockstep with the wrapped code', (
      tester,
    ) async {
      await _pumpNarrowWrappedText(tester);

      final editor = _editorScrollable(tester);
      final gutter = _gutterScrollable(tester);

      // The gutter is one row per logical line, so its rows have to be as tall
      // as the wrapped code renders them: an extent that disagrees leaves the
      // numbers pointing at the wrong lines as soon as the user scrolls.
      expect(
        _contentHeight(gutter),
        _contentHeight(editor),
        reason: 'the gutter and the code must scroll over the same content',
      );

      editor.position.jumpTo(2000);
      await tester.pumpAndSettle();
      expect(gutter.position.pixels, editor.position.pixels);

      gutter.position.jumpTo(60);
      await tester.pumpAndSettle();
      expect(editor.position.pixels, gutter.position.pixels);
    });

    testWidgets('without wrapping the gutter keeps one row per line', (
      tester,
    ) async {
      final controller = CodeController(
        text: List.generate(30, (i) => 'line $i ${'y' * 100}').join('\n'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: CodeField(
                controller: controller,
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Unwrapped long lines scroll horizontally instead of reflowing, so
      // every line is still one visual row and the two extents already agree:
      // the wrapped-row measurement must not disturb this layout.
      expect(
        _contentHeight(_gutterScrollable(tester)),
        _contentHeight(_editorScrollable(tester)),
      );
    });
  });
}
