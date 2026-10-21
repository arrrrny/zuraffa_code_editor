import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart';
import 'package:zuraffa_code_editor/src/code/code_lines_builder.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/markup_fallback.dart';

void main() {
  group('MarkupFallbackFoldableBlockParser', () {
    /// Parses [text] and returns the parser that parsed it.
    MarkupFallbackFoldableBlockParser parse(String text) {
      final parser = MarkupFallbackFoldableBlockParser();
      parser.parse(
        highlighted: Result(relevance: 0, nodes: [Node(value: text)]),
        serviceCommentsSources: const {},
        lines: CodeLinesBuilder.textToCodeLines(
          text: text,
          readonlyCommentsByLine: const {},
        ),
      );
      return parser;
    }

    test('it refuses a result that is not a single node', () {
      final parser = MarkupFallbackFoldableBlockParser();

      expect(
        () => parser.parse(
          highlighted: Result(
            relevance: 0,
            nodes: [
              Node(value: 'a'),
              Node(value: 'b'),
            ],
          ),
          serviceCommentsSources: const {},
          lines: CodeLinesBuilder.textToCodeLines(
            text: 'ab',
            readonlyCommentsByLine: const {},
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('it refuses a result that has no node at all', () {
      final parser = MarkupFallbackFoldableBlockParser();

      expect(
        () => parser.parse(
          highlighted: Result(relevance: 0),
          serviceCommentsSources: const {},
          lines: CodeLinesBuilder.textToCodeLines(
            text: '',
            readonlyCommentsByLine: const {},
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a less than that opens no name is a piece of text', () {
      final parser = parse('a < b\n<div>\n</div>\n');

      // The `<` of the comparison opens no tag, so the block of the element
      // is the one the parser finds.
      expect(parser.blocks, hasLength(1));
      expect(parser.blocks.single.firstLine, 1);
      expect(parser.blocks.single.lastLine, 2);
    });

    test('it skips a CDATA section', () {
      final parser = parse('<![CDATA[ <div> ]]>\n<div>\n</div>\n');

      expect(parser.blocks, hasLength(1));
      expect(parser.blocks.single.firstLine, 1);
    });

    test('it skips a comment and counts the lines it spans', () {
      final parser = parse('<!--\n\n-->\n<div>\n</div>\n');

      // The comment covers the first three lines, so the element starts on
      // the fourth one.
      expect(parser.blocks, hasLength(1));
      expect(parser.blocks.single.firstLine, 3);
      expect(parser.blocks.single.lastLine, 4);
    });

    test('it skips a comment that is never closed', () {
      final parser = parse('<!-- never closed\n<div>\n</div>\n');

      expect(parser.blocks, isEmpty);
    });

    test('it finds the blocks of the elements', () {
      final parser = parse('<div>\n<span>\n</span>\n</div>\n');

      expect(parser.blocks, hasLength(2));
      expect(parser.blocks.first.firstLine, 0);
      expect(parser.blocks.first.lastLine, 3);
      expect(parser.blocks.last.firstLine, 1);
      expect(parser.blocks.last.lastLine, 2);
    });
  });
}
