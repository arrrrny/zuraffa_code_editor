import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// CRLF documents: every `CodeLine` but the last keeps a full `\r\n` line break,
/// so the wrapping row measurement has to strip both the feed *and* the carriage
/// return before it lays the line out, otherwise it measures two rows per line
/// and the gutter drifts away from the editor.
void main() {
  testWidgets('a wrapped CRLF document measures one row per line', (wt) async {
    final controller = CodeController(text: 'a\r\nb\r\nc\r\n');
    addTearDown(controller.dispose);

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 300,
            child: CodeField(
              controller: controller,
              wrap: true,
              textStyle: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();

    expect(controller.code.lines.lines, hasLength(4));
    expect(controller.code.lines.lines.first.text, endsWith('\r\n'));
    expect(controller.text, 'a\r\nb\r\nc\r\n');

    wt.binding.focusManager.primaryFocus?.unfocus();
    await wt.pumpAndSettle();
  });
}
