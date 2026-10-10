import 'package:zuraffa_code_editor/src/gutter/fold_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// Covers the two sides of the fold toggle's callback: the gutter builds an
/// unfold action for a folded block and a fold action for an unfolded one, and
/// both have to reach the controller.
void main() {
  const source =
      'class A {\n'
      '  void m() {\n'
      '    int a;\n'
      '  }\n'
      '  void n() {\n'
      '    int b;\n'
      '  }\n'
      '}\n';

  testWidgets('tapping the toggle of a folded block unfolds it again', (
    wt,
  ) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final controller = await pumpController(wt, source);

    // `class A {` spans 0..7; fold it, then turn it back on through the gutter
    // the way a user would.
    controller.foldAt(0);
    await wt.pumpAndSettle();

    expect(controller.code.foldedBlocks, isNotEmpty);

    final foldedToggle = wt.widget<FoldToggle>(find.byType(FoldToggle).first);
    expect(foldedToggle.isFolded, isTrue);

    await wt.tap(find.byType(FoldToggle).first);
    await wt.pumpAndSettle();

    expect(controller.code.foldedBlocks, isEmpty);
    expect(controller.text, source);
  });

  testWidgets('tapping the toggle of an unfolded block folds it', (wt) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final controller = await pumpController(wt, source);

    expect(controller.code.foldedBlocks, isEmpty);

    await wt.tap(find.byType(FoldToggle).first);
    await wt.pumpAndSettle();

    expect(controller.code.foldedBlocks, isNotEmpty);
    expect(controller.code.visibleText, isNot(source));
  });
}
