import 'package:tuple/tuple.dart';
import 'package:zuraffa_code_editor/src/code/code_lines_builder.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/fallback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart';

void main() {
  group('FallbackFoldableBlockParser', () {
    // The parser only ever runs on a highlight result that carries the whole
    // document as one node, so anything else is a programming error rather
    // than something to recover from.
    final lines = CodeLinesBuilder.textToCodeLines(
      text: 'void main() {}',
      readonlyCommentsByLine: const {},
    );

    test('rejects a highlight result that is not a single node', () {
      final parser = FallbackFoldableBlockParser(
        importPrefixes: const ['import'],
        singleLineCommentSequences: const ['//'],
      );

      expect(
        () => parser.parse(
          highlighted: Result(
            nodes: [
              Node(value: 'a'),
              Node(value: 'b'),
            ],
          ),
          serviceCommentsSources: const {},
          lines: lines,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('A single-node highlighted result is required'),
          ),
        ),
      );
    });

    test('rejects a single node that carries no text', () {
      final parser = FallbackFoldableBlockParser(
        importPrefixes: const ['import'],
        singleLineCommentSequences: const ['//'],
      );

      expect(
        () => parser.parse(
          highlighted: Result(nodes: [Node(value: null)]),
          serviceCommentsSources: const {},
          lines: lines,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No text found in the highlighted result'),
          ),
        ),
      );
    });

    test('parses a well-formed single-node result', () {
      const text = '/* a\nb */\nvoid main() {}\n';
      final parser = FallbackFoldableBlockParser(
        importPrefixes: const ['import'],
        multilineCommentSequences: const [Tuple2('/*', '*/')],
        singleLineCommentSequences: const ['//'],
      );

      parser.parse(
        highlighted: Result(nodes: [Node(value: text)]),
        serviceCommentsSources: const {},
        lines: CodeLinesBuilder.textToCodeLines(
          text: text,
          readonlyCommentsByLine: const {},
        ),
      );

      // One multiline-comment block, closed on the second line.
      expect(parser.blocks.map((b) => '${b.firstLine}..${b.lastLine}'), [
        '0..1',
      ]);
    });
  });
}
