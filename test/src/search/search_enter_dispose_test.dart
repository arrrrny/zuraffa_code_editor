import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Related regression: https://github.com/arrrrny/zuraffa_code_editor/issues/4
/// (upstream akvelon/flutter-code-editor#299)
///
/// The Enter handler in the search controller awaits a zero-delay future and
/// then requests focus on the pattern field. If the widget and controller are
/// disposed inside that gap (route pop, tab switch), the continuation must not
/// touch the disposed controller.
///
/// Note on modern Flutter: `requestFocus` on a detached (disposed) FocusNode
/// is a no-op, so the continuation no longer throws on current toolchains. The
/// guard below pins the requested hardening — no exception, no notification —
/// and keeps the async gap honest if Flutter's focus internals change again.
void main() {
  testWidgets('Enter in search + dispose inside the async gap does not throw', (
    wt,
  ) async {
    final controller = CodeController(text: 'hello\nworld\n');

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );

    controller.searchController.showSearch();
    await wt.pump();
    var notifiedAfterDispose = false;
    controller.searchController.addListener(() => notifiedAfterDispose = true);

    // Enter is handled by the pattern field's FocusNode: schedules the async
    // continuation that requests focus after a microtask.
    await wt.sendKeyEvent(LogicalKeyboardKey.enter);

    // Tear the whole thing down before the continuation runs.
    await wt.pumpWidget(const SizedBox());
    controller.dispose();
    await wt.pump(const Duration(milliseconds: 10));

    expect(wt.takeException(), isNull);
    expect(
      notifiedAfterDispose,
      isFalse,
      reason: 'disposed controller must stay silent',
    );
  });

  testWidgets('Enter in search still moves focus to the pattern field', (
    wt,
  ) async {
    final controller = CodeController(text: 'hello\nworld\n');
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );

    controller.searchController.showSearch();
    await wt.pump();
    expect(
      controller.searchController.patternFocusNode.hasFocus,
      isTrue,
      reason: 'showing search focuses the pattern field',
    );

    await wt.sendKeyEvent(LogicalKeyboardKey.enter);
    await wt.pump(const Duration(milliseconds: 10));

    expect(
      controller.searchController.patternFocusNode.hasFocus,
      isTrue,
      reason: 'Enter returns focus to the pattern field (happy path)',
    );

    // showSearch() starts a periodic hiding timer; cancel it so the test
    // binding ends with no pending timers (same convention as
    // test/src/search/show_hide_search_test.dart).
    controller.searchController.hideSearch(returnFocusToCodeField: false);
    await wt.pump();
  });
}
