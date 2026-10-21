import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  testWidgets('the re_editor path shows the autocomplete popup', (
    tester,
  ) async {
    final controller = CodeController();
    controller.autocompleter.setCustomWords(['post', 'postalCode']);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeField(
            controller: controller,
            renderer: CodeFieldRenderer.reEditor,
          ),
        ),
      ),
    );
    await tester.pump();

    controller.value = const TextEditingValue(
      text: 'HttpMethod.po',
      selection: TextSelection.collapsed(offset: 13),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('post'), findsOneWidget);
    expect(find.text('postalCode'), findsOneWidget);

    // The controller debounces its analysis; let it run so it leaves no
    // timer behind.
    await tester.pump(const Duration(milliseconds: 600));
  });
}
