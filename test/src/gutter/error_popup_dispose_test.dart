import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/analyzer/models/issue.dart';
import 'package:zuraffa_code_editor/src/analyzer/models/issue_type.dart';
import 'package:zuraffa_code_editor/src/gutter/error.dart';

/// Regression: https://github.com/arrrrny/zuraffa_code_editor/issues/4
/// (upstream akvelon/flutter-code-editor#299)
///
/// The error-icon popup schedules a 50ms delayed `setState` on mouse exit, to
/// let the pointer travel from the icon onto the popup itself. If the widget is
/// disposed inside that window (route pop, tab switch, list scroll-away), the
/// callback ran `setState` on an unmounted State and threw.
void main() {
  const issue = Issue(line: 1, message: 'boom', type: IssueType.error);

  testWidgets('Disposing during the 50ms popup-close delay does not throw', (
    wt,
  ) async {
    var showGutter = true;
    StateSetter? setBody;

    // The GutterErrorWidget is swappable inside a host that stays mounted, so
    // the unmount below mirrors a route pop or scroll-away: the widget (and
    // its State) go away while the enclosing MaterialApp Overlay survives.
    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setBody = setState;
              return showGutter
                  ? const Center(child: GutterErrorWidget(issue, TextStyle()))
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final gesture = await wt.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Hover the icon: opens the popup overlay.
    await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
    await wt.pump();

    // Leave the icon: schedules the delayed close.
    await gesture.moveTo(const Offset(-500, -500));
    await wt.pump();

    // Dispose inside the 50ms window, then let the delay elapse.
    showGutter = false;
    setBody!.call(() {});
    await wt.pump();
    await wt.pump(const Duration(milliseconds: 60));

    expect(wt.takeException(), isNull);
    // The popup entry must not outlive its widget in the still-mounted
    // Overlay.
    expect(
      find.text('boom'),
      findsNothing,
      reason: 'unmounted GutterErrorWidget must remove its popup OverlayEntry',
    );
  });

  testWidgets('Popup still closes after the mouse leaves it (happy path)', (
    wt,
  ) async {
    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Center(child: GutterErrorWidget(issue, TextStyle())),
        ),
      ),
    );

    final gesture = await wt.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(wt.getCenter(find.byType(GutterErrorWidget)));
    await wt.pump();
    expect(find.text('boom'), findsOneWidget, reason: 'popup opened on hover');

    await gesture.moveTo(const Offset(-500, -500));
    await wt.pump(const Duration(milliseconds: 60));
    expect(find.text('boom'), findsNothing, reason: 'popup closed after exit');
  });
}
