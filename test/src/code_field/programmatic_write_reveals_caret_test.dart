import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// A host writes the document line by line and keeps the caret on the line it
/// just wrote — the shape a "paste these N lines in" or an incremental loader
/// produces. `CodeField` must reveal that caret, exactly as it reveals one a
/// keystroke moved.
///
/// The typing path already does: `EditableText` reveals the caret from
/// `userUpdateTextEditingValue`, the method the platform's input connection
/// delivers through. A controller write goes through
/// `_didChangeTextEditingValue` instead, which the framework deliberately
/// keeps free of a reveal — it only rescues an invalid selection and updates
/// the remote value. So a `CodeController` write moves the caret with no
/// scroll and it walks off the bottom of the viewport, which is #149.

void main() {
  ScrollableState editableScrollable(WidgetTester tester) {
    return tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(EditableText),
        matching: find.byType(Scrollable),
      ),
    );
  }

  Widget host(CodeController controller, {ScrollBehavior? behavior}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 200,
          child: ScrollConfiguration(
            behavior: behavior ?? const MaterialScrollBehavior(),
            child: CodeField(
              renderer: CodeFieldRenderer.textField,
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a programmatic line-by-line write reveals the caret', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    var text = '';
    for (var i = 0; i < 40; i++) {
      text = '${text}line $i\n';
      controller.text = text;
      controller.selection = TextSelection.collapsed(offset: text.length);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final vertical = editableScrollable(tester);

    expect(
      vertical.position.pixels,
      greaterThan(0),
      reason:
          'a write that walks the caret past the bottom of the viewport must '
          'reveal it, the way a keystroke does',
    );

    final gutter = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(GutterWidget),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      gutter.position.pixels,
      vertical.position.pixels,
      reason: 'the gutter must follow the field (the scroll views are linked)',
    );

    // Stop the caret blink timer so the binding does not see it pending.
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // The analysis debounce is a 500 ms timer on the controller.
    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a write that walks the caret back up reveals it upward', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    controller.text = List.generate(40, (i) => 'line $i').join('\n');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    await tester.pumpAndSettle();

    final vertical = editableScrollable(tester);
    expect(vertical.position.pixels, greaterThan(0));

    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();

    expect(
      vertical.position.pixels,
      lessThan(3),
      reason:
          'a caret the host moved back to the top of the document must be '
          'revealed upward, not left off the top of the viewport',
    );

    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a caret already in view leaves the scroll alone', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    controller.text = List.generate(40, (i) => 'line $i').join('\n');
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();

    final before = editableScrollable(tester).position.pixels;

    controller.selection = const TextSelection.collapsed(offset: 8);
    await tester.pumpAndSettle();

    expect(
      editableScrollable(tester).position.pixels,
      before,
      reason: 'a reveal must only ever scroll, never scroll for its own sake',
    );

    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a write while the field is unfocused leaves the scroll alone', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    var text = '';
    for (var i = 0; i < 40; i++) {
      text = '${text}line $i\n';
      controller.text = text;
      controller.selection = TextSelection.collapsed(offset: text.length);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final vertical = editableScrollable(tester);

    expect(
      vertical.position.pixels,
      0,
      reason:
          'a host that loads a document the user has not focused yet must not '
          'have the viewport yanked to the caret — the framework reveals on '
          'the focus change instead',
    );

    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a write that names no selection puts the caret at the end', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Assigning `text` alone carries the selection a fresh TextEditingValue
    // holds — collapsed at -1, no position at all — and the field repairs it
    // to the end, which is where the reveal then finds the caret.
    controller.text = List.generate(40, (i) => 'line $i').join('\n');
    await tester.pumpAndSettle();

    expect(
      controller.selection,
      TextSelection.collapsed(offset: controller.text.length),
      reason: 'the field moves the caret to the end of what was written',
    );
    expect(
      editableScrollable(tester).position.pixels,
      greaterThan(0),
      reason:
          'a caret at the end of the written text is revealed like any other',
    );

    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a field the host made unscrollable is not scrolled', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ScrollConfiguration(
              behavior: const _NeverScrollableScrollBehavior(),
              child: CodeField(
                renderer: CodeFieldRenderer.textField,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    var text = '';
    for (var i = 0; i < 40; i++) {
      text = '${text}line $i\n';
      controller.text = text;
      controller.selection = TextSelection.collapsed(offset: text.length);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(
      editableScrollable(tester).position.pixels,
      0,
      reason:
          'a host that made the field unscrollable has taken scrolling off '
          'the table, and a reveal must not put it back',
    );

    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a reveal the host unmounts mid-frame is dropped', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    controller.text = List.generate(40, (i) => 'line $i').join('\n');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    // This builds the frame the reveal was scheduled for, and the field is
    // gone by the time it runs.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );

    expect(tester.takeException(), isNull);

    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a reveal never takes over an offset that is moving', (
    tester,
  ) async {
    final controller = CodeController(text: '');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    controller.text = List.generate(40, (i) => 'line $i').join('\n');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    await tester.pumpAndSettle();

    final vertical = editableScrollable(tester);
    expect(
      vertical.position.pixels,
      greaterThan(0),
      reason: 'the write above reveals the caret at the bottom',
    );

    // The field is on its way back to the top — the framework's own reveal on
    // a keystroke looks exactly like this, and so does a host animating the
    // field while it loads. Nothing has ticked yet, so the offset is still
    // where the animation started it.
    vertical.position.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
    await tester.pump();
    final moving = vertical.position.pixels;
    expect(
      vertical.position.isScrollingNotifier.value,
      isTrue,
      reason: 'the premise: an animation is driving the offset right now',
    );

    // Write past the bottom anyway, so a reveal that ran would have to scroll.
    controller.text = '${controller.text}one more line\n';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    await tester.pump();

    expect(
      vertical.position.pixels,
      moving,
      reason:
          'the offset belongs to whoever is already moving it, and the reveal '
          'must not jump the field off it — least of all on the typing path, '
          'where the framework is still animating the caret it just saw',
    );

    await tester.pumpAndSettle();

    controller.dismiss();
    await tester.pump(const Duration(seconds: 10));
  });
}

class _NeverScrollableScrollBehavior extends ScrollBehavior {
  const _NeverScrollableScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const NeverScrollableScrollPhysics();
}
