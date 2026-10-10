import 'package:zuraffa_code_editor/src/single_line_comments/parser/single_line_comment_parser.dart';
import 'package:zuraffa_code_editor/src/single_line_comments/parser/single_line_comments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AbstractSingleLineCommentParser', () {
    test('getCommentsByLines keys the parsed comments by their line', () {
      const text =
          '// first\n'
          'void main() {}\n'
          '  // second\n'
          '  // third\n';

      final parser = SingleLineCommentParser.parseHighlighted(
        text: text,
        highlighted: null,
        singleLineCommentSequences: const ['//'],
      );

      final byLines = parser.getCommentsByLines();

      expect(byLines.keys.toList(), [0, 2, 3]);
      expect(byLines[0]!.lineIndex, 0);
      expect(byLines[2]!.lineIndex, 2);
      expect(byLines[3]!.lineIndex, 3);
    });
  });

  group('SingleLineComments', () {
    test('every entry is a comment sequence, not a mode name', () {
      // The map's values are what the parsers search for; the keys identify
      // the mode they belong to.
      expect(SingleLineComments.byMode.length, greaterThan(0));

      for (final sequences in SingleLineComments.byMode.values) {
        expect(sequences, isNotEmpty);
        for (final sequence in sequences) {
          expect(sequence, isNotEmpty);
        }
      }
    });
  });
}
