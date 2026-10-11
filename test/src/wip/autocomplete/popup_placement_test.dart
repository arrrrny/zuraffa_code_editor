import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup_controller.dart';

/// Where the popup lands. Upstream `akvelon/flutter-code-editor#205` (our #84)
/// reported the popup getting cut off: it is inserted into the full-screen
/// overlay at *window* coordinates, but every bound it measured against was
/// the *editor's* render box, and its horizontal clamp subtracted an
/// unexplained 100 px (the `TODO(nausharipov)` in `popup.dart`). So an editor
/// narrower than the popup plus that fudge pushed the popup off the left edge,
/// and the vertical flip refused outright when the editor was shorter than the
/// popup's maximum height.
///
/// The bare popup is pumped directly — no field — with the geometry the field
/// would hand it, so each case pins one placement decision. `window` is the
/// rectangle the popup has to stay inside: the field passes the real window's
/// size, not the editor's render box.
void main() {
  const suggestions = ['alpha', 'beta', 'gamma'];
  const window = Size(800, 600);

  Future<Positioned> pumpPopup(
    WidgetTester wt, {
    required Size popupWindow,
    required Offset caretOffset,
    required Offset flippedCaretOffset,
    List<String> items = suggestions,
  }) async {
    final controller = PopupController(onCompletionSelected: () {});
    controller.show(items);

    await wt.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Popup(
              controller: controller,
              editingWindowSize: popupWindow,
              normalOffset: caretOffset,
              flippedOffset: flippedCaretOffset,
              parentFocusNode: FocusNode(),
              style: const TextStyle(color: Colors.black),
              backgroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
    await wt.pumpAndSettle();

    return wt.widget<Positioned>(find.byType(Positioned));
  }

  void expectRowsInsideWindow(WidgetTester wt, Size bounds) {
    final rows = find.byType(InkWell);
    for (var i = 0; i < rows.evaluate().length; i++) {
      final rect = wt.getRect(rows.at(i));
      expect(
        rect.left,
        greaterThanOrEqualTo(0),
        reason: 'row $i starts off the left edge of the window',
      );
      expect(
        rect.right,
        lessThanOrEqualTo(bounds.width),
        reason: 'row $i runs past the right edge of the window',
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(bounds.height),
        reason: 'row $i runs past the bottom edge of the window',
      );
    }
  }

  testWidgets('a caret past the popup width is pulled back inside the window '
      '(SC-003)', (wt) async {
    // A window as wide as a phone with the caret deep in it: the old clamp put
    // the popup at 390 - 300 - 100 = -10, off the left edge.
    final positioned = await pumpPopup(
      wt,
      popupWindow: const Size(390, 600),
      caretOffset: const Offset(150, 100),
      flippedCaretOffset: const Offset(150, 0),
    );

    expect(positioned.left, 90, reason: 'clamped to the window: 390 - 300');
    expectRowsInsideWindow(wt, const Size(390, 600));
  });

  testWidgets('a caret with room to its right follows the caret (SC-003)', (
    wt,
  ) async {
    // The unexplained -100 only existed because the clamp was derived from the
    // editor box; measured against the window, a caret at 250 in an 800 px
    // window simply keeps its place.
    final positioned = await pumpPopup(
      wt,
      popupWindow: window,
      caretOffset: const Offset(250, 100),
      flippedCaretOffset: const Offset(250, 0),
    );

    expect(positioned.left, 250);
    expectRowsInsideWindow(wt, window);
  });

  testWidgets('a caret near the bottom of the window flips the popup above '
      'it (SC-004)', (wt) async {
    // Three rows need 60 px; there is no room for them at 572, so the popup
    // flips above the caret and is pushed to the bottom of its rectangle.
    final positioned = await pumpPopup(
      wt,
      popupWindow: window,
      caretOffset: const Offset(70, 572),
      flippedCaretOffset: const Offset(70, 442),
    );

    expect(positioned.top, 442);
    expectRowsInsideWindow(wt, window);
  });

  testWidgets('room below keeps the popup below the caret (SC-004)', (
    wt,
  ) async {
    // One suggestion needs a 20 px row; the constant 100 used to force a flip
    // even though 560 + 20 fits under the window's bottom edge.
    final positioned = await pumpPopup(
      wt,
      popupWindow: window,
      caretOffset: const Offset(70, 560),
      flippedCaretOffset: const Offset(70, 430),
      items: const ['alpha'],
    );

    expect(positioned.top, 560, reason: 'not flipped: there is room below');
    expectRowsInsideWindow(wt, window);
  });

  testWidgets('a single suggestion just above the window bottom flips '
      '(SC-004)', (wt) async {
    // One row renders at bodyMedium's height (20 px) — the ambient style the
    // row's `Material` installs. Measuring a shorter row (the bare tree's
    // fallback `TextStyle()`, 14 px) calls 582 + 14 <= 600 room enough, leaves
    // the popup unflipped at 582, and the rendered row runs 582..602 — past
    // the bottom edge this clamp exists to keep inside.
    final positioned = await pumpPopup(
      wt,
      popupWindow: window,
      caretOffset: const Offset(70, 582),
      flippedCaretOffset: const Offset(70, 460),
      items: const ['alpha'],
    );

    expect(
      positioned.top,
      460,
      reason: 'flipped: 582 + one 20 px row does not fit under the bottom',
    );
    expectRowsInsideWindow(wt, window);
  });

  testWidgets('many suggestions are measured at the capped height (SC-004)', (
    wt,
  ) async {
    // Six rows would be 120 px of text, but the popup never grows past its
    // maximum height — it scrolls instead. Deciding the flip on 120 would flip
    // a popup that has room at 495 + 100.
    final positioned = await pumpPopup(
      wt,
      popupWindow: window,
      caretOffset: const Offset(70, 495),
      flippedCaretOffset: const Offset(70, 365),
      items: const ['a', 'b', 'c', 'd', 'e', 'f'],
    );

    expect(
      positioned.top,
      495,
      reason: 'the cap, not the raw row count, decides',
    );
    expectRowsInsideWindow(wt, window);
  });

  testWidgets('a window narrower than the popup clamps to the left edge '
      '(SC-003 edge case)', (wt) async {
    // Nothing fits: the clamp must not produce a negative offset, and the
    // popup starts at the left edge rather than outside it.
    final positioned = await pumpPopup(
      wt,
      popupWindow: const Size(300, 600),
      caretOffset: const Offset(0, 100),
      flippedCaretOffset: const Offset(0, 0),
    );

    expect(positioned.left, 0);
    final firstRow = wt.getRect(find.byType(InkWell).first);
    expect(firstRow.left, greaterThanOrEqualTo(0));
  });

  testWidgets('an empty suggestion list still builds', (wt) async {
    // The popup is only ever shown with a non-empty list, but the height
    // arithmetic must not divide by or index into an empty one.
    final positioned = await pumpPopup(
      wt,
      popupWindow: window,
      caretOffset: const Offset(70, 560),
      flippedCaretOffset: const Offset(70, 430),
      items: const [],
    );

    expect(positioned.left, 70);
    expect(find.byType(InkWell), findsNothing);
  });
}
