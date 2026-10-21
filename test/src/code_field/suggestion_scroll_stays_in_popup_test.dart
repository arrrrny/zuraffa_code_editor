import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// #101 — scrolling the suggestion list must not scroll the editor.
///
/// Upstream `akvelon/flutter-code-editor#190` reported (video, 2022) that
/// scrolling the suggestion list also scrolled the editor. The popup lives in
/// the root overlay as a sibling of the editor's scroll view, so every pointer
/// input is resolved on a hit-test chain that contains the popup's list and
/// not the editor — the gesture has no path into the field. These drive the
/// real field (caret seeded, `popupController.show(...)`, the editor box small
/// enough to overflow) and pin that property: whatever reaches the popup stays
/// in the popup, and the editor's scroll position never moves.
void main() {
  /// The fixture: 40 lines in a 200 px viewport, so the editor's own scrollable
  /// really overflows and any leaked gesture would be visible.
  Future<CodeController> pumpEditor(
    WidgetTester tester, {
    bool insideOuterScroll = false,
  }) async {
    final controller = CodeController(
      text: '${List.generate(40, (i) => 'line $i').join('\n')}\n',
    );
    addTearDown(controller.dispose);
    final field = SizedBox(
      height: 200,
      width: 400,
      child: CodeField(
        renderer: CodeFieldRenderer.textField,
        controller: controller,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: insideOuterScroll ? SingleChildScrollView(child: field) : field,
        ),
      ),
    );
    return controller;
  }

  Future<void> showSuggestions(
    WidgetTester tester,
    CodeController controller,
    List<String> suggestions,
  ) async {
    controller.selection = const TextSelection.collapsed(offset: 0);
    controller.popupController.show(suggestions);
    await tester.pumpAndSettle();
  }

  ScrollableState editorScrollable(WidgetTester tester) {
    return tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(EditableText),
        matching: find.byType(Scrollable),
      ),
    );
  }

  ScrollableState popupScrollable(WidgetTester tester) {
    return tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(Popup),
        matching: find.byType(Scrollable),
      ),
    );
  }

  Offset popupCenter(WidgetTester tester) =>
      tester.getRect(find.byType(Popup)).center;

  group('Scrolling the suggestion list does not scroll the editor (#101)', () {
    testWidgets('the wheel over the list moves only the list', (tester) async {
      final controller = await pumpEditor(tester);
      await showSuggestions(
        tester,
        controller,
        List.generate(12, (i) => 'suggestion$i'),
      );

      expect(
        popupScrollable(tester).position.maxScrollExtent,
        greaterThan(0),
        reason: 'the fixture needs a list long enough to scroll',
      );
      expect(editorScrollable(tester).position.pixels, 0);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(popupCenter(tester)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
      await tester.pumpAndSettle();

      expect(
        popupScrollable(tester).position.pixels,
        greaterThan(0),
        reason: 'the wheel must still scroll the suggestion list',
      );
      expect(editorScrollable(tester).position.pixels, 0);
    });

    testWidgets('the wheel at the end of the list still moves nothing else', (
      tester,
    ) async {
      final controller = await pumpEditor(tester);
      await showSuggestions(
        tester,
        controller,
        List.generate(12, (i) => 'suggestion$i'),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(popupCenter(tester)));
      // To the end, then another wheel step at the end.
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 500)));
      await tester.pumpAndSettle();
      final popupEnd = popupScrollable(tester).position.pixels;
      expect(popupEnd, greaterThan(0));

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
      await tester.pumpAndSettle();

      expect(
        popupScrollable(tester).position.pixels,
        popupEnd,
        reason: 'the list clamps at its end',
      );
      expect(editorScrollable(tester).position.pixels, 0);
    });

    testWidgets('the wheel over a short list does not fall through', (
      tester,
    ) async {
      final controller = await pumpEditor(tester);
      await showSuggestions(tester, controller, ['alpha', 'beta', 'gamma']);

      expect(popupScrollable(tester).position.maxScrollExtent, 0);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(popupCenter(tester)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
      await tester.pumpAndSettle();

      expect(editorScrollable(tester).position.pixels, 0);
    });

    testWidgets('a drag past the end of the list stays in the list', (
      tester,
    ) async {
      final controller = await pumpEditor(tester);
      await showSuggestions(
        tester,
        controller,
        List.generate(12, (i) => 'suggestion$i'),
      );

      final gesture = await tester.startGesture(popupCenter(tester));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(popupScrollable(tester).position.maxScrollExtent, greaterThan(0));
      expect(
        popupScrollable(tester).position.pixels,
        greaterThan(0),
        reason: 'the drag scrolls the suggestion list',
      );
      expect(editorScrollable(tester).position.pixels, 0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        editorScrollable(tester).position.pixels,
        0,
        reason: 'the spring-back must not reach the editor either',
      );
    });

    testWidgets('a drag on a short list scrolls nothing', (tester) async {
      final controller = await pumpEditor(tester);
      await showSuggestions(tester, controller, ['alpha', 'beta', 'gamma']);

      final gesture = await tester.startGesture(popupCenter(tester));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(editorScrollable(tester).position.pixels, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the editor inside a scrollable page is equally protected', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, insideOuterScroll: true);
      await showSuggestions(
        tester,
        controller,
        List.generate(12, (i) => 'suggestion$i'),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(popupCenter(tester)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
      await tester.pumpAndSettle();

      expect(
        popupScrollable(tester).position.pixels,
        greaterThan(0),
        reason: 'the wheel still scrolls the suggestion list',
      );
      expect(editorScrollable(tester).position.pixels, 0);
    });
  });
}
