import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// `CodeField.expands: true` puts the editor inside an `Expanded` instead of a
/// `ConstrainedBox`, so a field can be sized by its parent rather than by its
/// content. Both layouts have to keep rendering.
void main() {
  const source =
      'void main() {\n'
      '  print(\'hello\');\n'
      '}\n';

  testWidgets('expands: true lays the field out inside its parent', (wt) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final controller = createController(source);
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: CodeField(controller: controller, expands: true)),
            ],
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();

    expect(find.byType(CodeField), findsOneWidget);
    // The text is still laid out — the `Expanded` wrapper must not swallow it.
    expect(find.textContaining('hello'), findsWidgets);
  });

  testWidgets('expands: false keeps the default content-sized layout', (
    wt,
  ) async {
    wt.view.physicalSize = const Size(800, 1000);
    wt.view.devicePixelRatio = 1.0;
    addTearDown(wt.view.reset);

    final controller = createController(source);
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );
    await wt.pumpAndSettle();

    expect(find.byType(CodeField), findsOneWidget);
    expect(find.textContaining('hello'), findsWidgets);
  });
}
