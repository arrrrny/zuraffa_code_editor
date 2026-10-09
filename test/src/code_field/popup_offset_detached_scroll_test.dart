import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Regression: https://github.com/arrrrny/zuraffa_code_editor/issues/10
/// (upstream akvelon/flutter-code-editor#275)
///
/// `CodeController.analyzeCode()` finishes on a later microtask and then calls
/// `notifyListeners()`, which reaches `_CodeFieldState._updatePopupOffset()`.
/// That reads `ScrollController.offset` for both the code field and the
/// horizontal wrapper. When neither scroll view has an attached position yet
/// (field built but not laid out — the analysis landing before the first
/// frame), `ScrollController.offset` throws
/// `ScrollController not attached to any scroll views` and every analysis
/// prints an exception to the console.
void main() {
  test('scrollOffsetOrZero() tolerates a controller with no attached view', () {
    final controller = ScrollController();

    // Without the guard this throws `ScrollController not attached to any
    // scroll views.` — the exception reported in upstream #275.
    expect(scrollOffsetOrZero(controller), 0);
  });

  testWidgets('scrollOffsetOrZero() tolerates multiple attached scroll views', (
    wt,
  ) async {
    final controller = ScrollController();

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: const SizedBox(height: 2000),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: const SizedBox(height: 2000),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Without the guard this throws `offset cannot be used when multiple
    // ScrollPositions are attached.`
    expect(scrollOffsetOrZero(controller), 0);
  });

  testWidgets('scrollOffsetOrZero() forwards an attached controller offset', (
    wt,
  ) async {
    final controller = ScrollController();

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: const SizedBox(height: 2000, width: 100),
          ),
        ),
      ),
    );

    controller.jumpTo(30);
    expect(scrollOffsetOrZero(controller), 30);
  });

  testWidgets('Analysis notification reaches an offstage field without error', (
    wt,
  ) async {
    final controller = CodeController(text: 'class A {}\n');

    // Offstage keeps the element tree (and so the controller listeners) alive
    // while skipping painting — but `RenderOffstage` still lays its child out
    // (see assessment.md → "Reproducibility"), so the internal scroll views
    // attach normally and this case is a happy-path smoke for an offstage
    // field. The detached path is pinned by the `scrollOffsetOrZero()` unit
    // tests above.
    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Offstage(
              offstage: true, child: CodeField(controller: controller)),
        ),
      ),
    );

    controller.text = 'class B {}\n';
    // The controller debounces analysis by 500ms.
    await wt.pump(const Duration(milliseconds: 600));

    expect(wt.takeException(), isNull);
  });

  testWidgets('Popup offset is still computed for a laid out field', (
    wt,
  ) async {
    final controller = CodeController(text: 'class A {}\n');

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );
    await wt.pump(const Duration(milliseconds: 600));

    controller.text = 'class B {}\n';
    await wt.pump(const Duration(milliseconds: 600));

    expect(wt.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}
