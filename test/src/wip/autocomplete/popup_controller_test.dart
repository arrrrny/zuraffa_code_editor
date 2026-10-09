import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup_controller.dart';

void main() {
  Future<PopupController> pumpList(
    WidgetTester tester, {
    required int itemCount,
    required double itemHeight,
  }) async {
    final controller = PopupController(onCompletionSelected: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollablePositionedList.builder(
            itemScrollController: controller.itemScrollController,
            itemPositionsListener: controller.itemPositionsListener,
            itemCount: itemCount,
            itemBuilder: (context, index) =>
                SizedBox(height: itemHeight, child: Text('item $index')),
          ),
        ),
      ),
    );
    return controller;
  }

  group('PopupController state', () {
    test('starts hidden, enabled, with the first item selected', () {
      final controller = PopupController(onCompletionSelected: () {});

      expect(controller.shouldShow, isFalse);
      expect(controller.enabled, isTrue);
      expect(controller.selectedIndex, 0);
    });

    test('selectedIndex notifies listeners', () {
      final controller = PopupController(onCompletionSelected: () {});
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.selectedIndex = 3;

      expect(controller.selectedIndex, 3);
      expect(notifications, 1);
    });

    test('show does nothing while disabled', () {
      final controller = PopupController(onCompletionSelected: () {})
        ..enabled = false;

      controller.show(const ['a', 'b']);

      expect(controller.shouldShow, isFalse);
    });

    test('hide clears shouldShow and notifies', () {
      final controller = PopupController(onCompletionSelected: () {})
        ..show(const ['a', 'b']);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.hide();

      expect(controller.shouldShow, isFalse);
      expect(notifications, 1);
    });

    test('getSelectedWord returns the selected suggestion', () {
      final controller = PopupController(onCompletionSelected: () {})
        ..show(const ['alpha', 'beta', 'gamma']);

      expect(controller.getSelectedWord(), 'alpha');

      controller.selectedIndex = 2;
      expect(controller.getSelectedWord(), 'gamma');
    });
  });

  group('PopupController with an attached list', () {
    testWidgets('show resets selection, reveals and scrolls to the top', (
      tester,
    ) async {
      final controller = await pumpList(tester, itemCount: 10, itemHeight: 100);

      controller.itemScrollController.jumpTo(index: 5);
      await tester.pump();

      controller.show(List.generate(10, (i) => 'suggestion $i'));
      await tester.pump();
      await tester.pump();

      expect(controller.shouldShow, isTrue);
      expect(controller.selectedIndex, 0);
      expect(controller.suggestions.first, 'suggestion 0');
      expect(controller.suggestions.length, 10);
      expect(
        controller.itemPositionsListener.itemPositions.value.map(
          (position) => position.index,
        ),
        contains(0),
      );
    });

    testWidgets('scrollByArrow down moves and wraps at the end', (
      tester,
    ) async {
      final controller = await pumpList(tester, itemCount: 3, itemHeight: 100);

      controller.show(const ['a', 'b', 'c']);
      await tester.pump();

      controller.scrollByArrow(ScrollDirection.down);
      expect(controller.selectedIndex, 1);

      controller.scrollByArrow(ScrollDirection.down);
      expect(controller.selectedIndex, 2);

      controller.scrollByArrow(ScrollDirection.down);
      expect(controller.selectedIndex, 0);
    });

    testWidgets('scrollByArrow up moves and wraps at the start', (
      tester,
    ) async {
      final controller = await pumpList(tester, itemCount: 3, itemHeight: 100);

      controller.show(const ['a', 'b', 'c']);
      await tester.pump();

      controller.scrollByArrow(ScrollDirection.up);
      expect(controller.selectedIndex, 2);

      controller.scrollByArrow(ScrollDirection.up);
      expect(controller.selectedIndex, 1);
    });

    testWidgets('scrollByArrow jumps for selections outside the viewport', (
      tester,
    ) async {
      // 600px viewport with 100px items: 6 visible of 10.
      final controller = await pumpList(tester, itemCount: 10, itemHeight: 100);

      controller.show(List.generate(10, (i) => 'item$i'));
      await tester.pump();

      controller.selectedIndex = 8;
      controller.scrollByArrow(ScrollDirection.down);
      await tester.pump();

      expect(controller.selectedIndex, 9);
      expect(
        controller.itemPositionsListener.itemPositions.value.any(
          (position) => position.index == 9,
        ),
        isTrue,
      );
    });

    testWidgets('scrollByArrow down reveals the next item, bottom-aligned', (
      tester,
    ) async {
      // 600px viewport with 100px items: 0-5 visible of 10, list at the top.
      final controller = await pumpList(tester, itemCount: 10, itemHeight: 100);

      controller.show(List.generate(10, (i) => 'item$i'));
      await tester.pump();

      // Step down into the first hidden item: hits the alignment jump.
      controller.selectedIndex = 5;
      controller.scrollByArrow(ScrollDirection.down);
      await tester.pump();

      expect(controller.selectedIndex, 6);
      final selected = controller.itemPositionsListener.itemPositions.value
          .firstWhere((position) => position.index == 6);
      expect(selected.itemLeadingEdge, greaterThanOrEqualTo(0));
      expect(selected.itemTrailingEdge, lessThanOrEqualTo(1));
    });
  });
}
