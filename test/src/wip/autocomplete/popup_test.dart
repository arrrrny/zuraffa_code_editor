import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup_controller.dart';

/// The completion popup is a wip module, but it is wired into the field, so its
/// item gestures are part of the editing surface: a tap moves the selection
/// and hands focus back to the editor, a double tap also commits the word.
///
/// Both handlers sit on the same InkWell, so the gesture arena holds a single
/// tap back until the double tap timeout has passed. Every tap below is
/// therefore followed by a `kDoubleTapTimeout`-sized pump, and every double tap
/// pumps a short gap between its two taps so they carry distinct timestamps.
void main() {
  const suggestions = ['alpha', 'beta', 'gamma'];
  final settleDoubleTap = kDoubleTapTimeout + const Duration(milliseconds: 100);

  Future<(PopupController, FocusNode, List<int>)> pumpPopup(
    WidgetTester wt,
  ) async {
    final completions = <int>[];
    final controller = PopupController(
      onCompletionSelected: () => completions.add(1),
    );
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    controller.show(suggestions);
    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: focusNode,
            child: Stack(
              children: [
                Popup(
                  controller: controller,
                  editingWindowSize: const Size(400, 600),
                  editorOffset: Offset.zero,
                  flippedOffset: Offset.zero,
                  normalOffset: Offset.zero,
                  parentFocusNode: focusNode,
                  style: const TextStyle(color: Colors.black),
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();

    return (controller, focusNode, completions);
  }

  testWidgets('renders the suggestions', (wt) async {
    final (controller, _, _) = await pumpPopup(wt);

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
    expect(controller.shouldShow, isTrue);
    expect(controller.selectedIndex, 0);
  });

  testWidgets('a tap on an item selects it and returns focus to the editor', (
    wt,
  ) async {
    final (controller, focusNode, completions) = await pumpPopup(wt);

    expect(focusNode.hasFocus, isFalse);

    await wt.tap(find.text('beta'));
    await wt.pump(settleDoubleTap);
    await wt.pumpAndSettle();

    expect(controller.selectedIndex, 1);
    expect(focusNode.hasFocus, isTrue);
    expect(
      completions,
      isEmpty,
      reason: 'a single tap only moves the selection, it does not commit',
    );
  });

  testWidgets('a double tap commits the selected item', (wt) async {
    final (controller, focusNode, completions) = await pumpPopup(wt);

    await wt.tap(find.text('gamma'));
    await wt.pump(const Duration(milliseconds: 50));
    await wt.tap(find.text('gamma'));
    await wt.pump(settleDoubleTap);
    await wt.pumpAndSettle();

    expect(controller.selectedIndex, 2);
    expect(focusNode.hasFocus, isTrue);
    expect(completions.length, 1);
  });
}
