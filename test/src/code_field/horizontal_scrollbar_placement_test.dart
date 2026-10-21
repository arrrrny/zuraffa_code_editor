library;

import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// #91 — a horizontal scrollbar for wide code, pinned to the viewport.
///
/// Upstream akvelon/flutter-code-editor#281 asks for an always-visible
/// horizontal scrollbar, and its body is the important half of the issue: the
/// reporter already tried adding one and it ended up "only visible at the bottom
/// of the scrollview, instead of always visible at the bottom of the screen".
/// A `Scrollbar` placed *inside* the scrollable scrolls away with the content,
/// which is the trap. A `Scrollbar` wrapped around the scroll view shares the
/// editor viewport's box, so it cannot drift.
///
/// The editor's code area, when `wrap` is false, is the horizontal
/// `SingleChildScrollView` in `_wrapInScrollView`
/// (`lib/src/code_field/code_field.dart:516`). That is the scroll view these
/// tests pin the bar to.
void main() {
  /// Long enough that the code area really overflows the 300x200 box the field
  /// is given, so a scroll bar has something to show.
  final wideLine = 'a' * 300;

  Future<void> pumpCodeField(
    WidgetTester wt, {
    required String text,
    bool wrap = false,
    CodeFieldRenderer renderer = CodeFieldRenderer.textField,
  }) async {
    final controller = createController(text);
    addTearDown(controller.dispose);
    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: CodeField(
              renderer: renderer,
              controller: controller,
              wrap: wrap,
            ),
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();
  }

  final horizontalScrollable = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axis == Axis.horizontal,
  );

  group('the horizontal scrollbar (#91)', () {
    testWidgets('a code area that cannot scroll shows no thumb', (wt) async {
      // Content that fits the viewport: a bar would be a lie about reach.
      await pumpCodeField(
        renderer: CodeFieldRenderer.textField,
        wt,
        text: 'int a = 1;\n',
      );
      expect(horizontalScrollable, findsOneWidget);
      expect(find.byType(Scrollbar), findsOneWidget);

      final bar = wt.widget<Scrollbar>(find.byType(Scrollbar));
      expect(
        bar.thumbVisibility,
        isFalse,
        reason: 'nothing to scroll means no reach to advertise',
      );
    });

    testWidgets('a code area that overflows horizontally has a bar', (
      wt,
    ) async {
      await pumpCodeField(
        renderer: CodeFieldRenderer.textField,
        wt,
        text: '$wideLine\nint a = 1;\n',
      );

      expect(find.byType(Scrollbar), findsOneWidget);
    });

    testWidgets('the bar is laid out with the viewport, not the content', (
      wt,
    ) async {
      await pumpCodeField(
        renderer: CodeFieldRenderer.textField,
        wt,
        text: '$wideLine\nint a = 1;\n',
      );

      // Exactly one bar: two would mean the bar was mounted somewhere it does
      // not belong, and the rect below would then measure the wrong one.
      expect(find.byType(Scrollbar), findsOneWidget);
      final bar = wt.getRect(find.byType(Scrollbar));
      final viewport = wt.getRect(horizontalScrollable);

      // The failure mode from the issue: the bar rides with the content, so it
      // sits below the visible area and is only reachable by scrolling. Its box
      // must be the scroll view's own viewport instead.
      expect(bar.top, greaterThanOrEqualTo(viewport.top));
      expect(bar.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
      // And it is at the bottom of that viewport, not the top of it.
      expect(bar.bottom, greaterThanOrEqualTo(viewport.bottom - 0.01));
    });

    testWidgets('the bar belongs to the field\'s own scroll view', (wt) async {
      await pumpCodeField(
        renderer: CodeFieldRenderer.textField,
        wt,
        text: '$wideLine\nint a = 1;\n',
      );

      // The association is the whole point: a bar bound to some other scroll
      // view would scroll something else. The code area's horizontal scrollable
      // and the bar drive the same controller, so dragging one moves the other.
      final scrollable = wt.widget<Scrollable>(horizontalScrollable);
      final bar = wt.widget<Scrollbar>(find.byType(Scrollbar));

      expect(bar.controller, isNotNull);
      expect(bar.controller, same(scrollable.controller));
    });

    testWidgets('the bar is always visible, not only while scrolling', (
      wt,
    ) async {
      await pumpCodeField(
        renderer: CodeFieldRenderer.textField,
        wt,
        text: '$wideLine\nint a = 1;\n',
      );

      final bar = wt.widget<Scrollbar>(find.byType(Scrollbar));
      expect(
        bar.thumbVisibility,
        isTrue,
        reason:
            'a thumb that only appears during a drag leaves the affordance '
            'invisible in exactly the state a wide file is in',
      );
      expect(bar.interactive, isTrue);
    });

    testWidgets('wrap: true reflows instead of scrolling and has no bar', (
      wt,
    ) async {
      await pumpCodeField(
        renderer: CodeFieldRenderer.textField,
        wt,
        text: '$wideLine\nint a = 1;\n',
        wrap: true,
      );

      // Soft wrapping removes the horizontal extent, and `_wrapInScrollView`
      // returns before it ever builds a scroll view or a bar.
      expect(find.byType(Scrollbar), findsNothing);
      expect(horizontalScrollable, findsNothing);
    });

    testWidgets('the vertical scrollbar is unaffected', (wt) async {
      await pumpCodeField(
        renderer: CodeFieldRenderer.textField,
        wt,
        text: 'int a = 1;\n',
      );

      // The fix is horizontal only: a short document's vertical scrollbar
      // situation must be exactly what it was.
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(
        wt.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isFalse,
      );
      final verticals = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      );
      expect(verticals, findsWidgets);
    });
  });
}
