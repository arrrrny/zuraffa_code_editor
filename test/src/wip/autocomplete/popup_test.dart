import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup_controller.dart';

/// The completion popup is a wip module, but it is wired into the field, so its
/// item gestures are part of the editing surface: a single tap commits the word
/// it sits on and hands focus back to the editor, exactly like the Enter path.
///
/// Upstream `akvelon/flutter-code-editor#205` (our #84) reported the mobile
/// symptom: the commit used to hang off `onDoubleTap`, so the first tap only
/// moved the highlight and the word was never inserted.
void main() {
  const suggestions = ['alpha', 'beta', 'gamma'];

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

  testWidgets('a tap on an item commits it and returns focus to the editor', (
    wt,
  ) async {
    final (controller, focusNode, completions) = await pumpPopup(wt);

    expect(focusNode.hasFocus, isFalse);

    await wt.tap(find.text('beta'));
    // Far under kDoubleTapTimeout: the commit may not wait for the
    // double tap timeout to expire.
    await wt.pump(const Duration(milliseconds: 100));
    await wt.pumpAndSettle();

    expect(controller.selectedIndex, 1);
    expect(focusNode.hasFocus, isTrue);
    expect(completions.length, 1);
  });

  testWidgets('the tapped row is the one committed', (wt) async {
    final (controller, _, completions) = await pumpPopup(wt);

    await wt.tap(find.text('gamma'));
    await wt.pump(const Duration(milliseconds: 100));
    await wt.pumpAndSettle();

    expect(controller.selectedIndex, 2);
    expect(completions.length, 1);
  });
}
