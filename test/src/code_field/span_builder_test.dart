import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart';
import 'package:zuraffa_code_editor/src/code/code.dart';
import 'package:zuraffa_code_editor/src/code_field/span_builder.dart';

void main() {
  group('SpanBuilder', () {
    test('it walks the tree of a document that has a highlight', () {
      final code = Code(
        text: 'a\nb\n',
        highlighted: Result(relevance: 0, nodes: [Node(value: 'a\nb\n')]),
      );

      final builder = SpanBuilder(code: code, theme: null);
      final span = builder.build();

      expect(span.toPlainText(), 'a\nb\n');
    });

    test('it clamps the line index to the last line of the document', () {
      // The tree carries more lines than the document has, which is what a
      // tree that was cut wrong looks like. The index must not run past the
      // document's own lines.
      final code = Code(
        text: 'a',
        highlighted: Result(relevance: 0, nodes: [Node(value: 'a\nb\nc')]),
      );

      final builder = SpanBuilder(code: code, theme: null);
      final span = builder.build();

      expect(span.toPlainText(), 'a\nb\nc');
    });

    test('it draws the plain text of a document that has no highlight', () {
      final code = Code(text: 'a\nb\n');

      final builder = SpanBuilder(code: code, theme: null);
      final span = builder.build();

      expect(span.toPlainText(), 'a\nb\n');
    });
  });
}
