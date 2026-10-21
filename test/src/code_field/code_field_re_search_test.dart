import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  testWidgets('the re_editor path finds the matches of the search panel', (
    tester,
  ) async {
    final controller = CodeController();
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

    controller.value = const TextEditingValue(
      text: 'alpha\nbeta\nalpha',
      selection: TextSelection.collapsed(offset: 0),
    );
    await tester.pump();

    controller.searchController.showSearch();
    await tester.pump();

    controller.searchController.settingsController.patternController.text =
        'alpha';
    await tester.pump();

    // The panel counts the matches.
    expect(
      controller.searchController.navigationController.value.totalMatchCount,
      2,
    );

    // And the editor highlights them: the find controller of the editor
    // holds one selection per match.
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.findController!.allMatchSelections!.length, 2);

    // Close the search again and let the pending timers run out, so none of
    // them is left behind when the tree is torn down.
    controller.searchController.hideSearch(returnFocusToCodeField: false);
    await tester.pump(const Duration(milliseconds: 1200));
  });
}
