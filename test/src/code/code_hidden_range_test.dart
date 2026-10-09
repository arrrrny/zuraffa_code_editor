import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/src/code/code.dart';
import 'package:zuraffa_code_editor/src/folding/foldable_block.dart';
import 'package:zuraffa_code_editor/src/folding/foldable_block_type.dart';
import 'package:zuraffa_code_editor/src/named_sections/parsers/brackets_start_end.dart';

// void main() {
//   int x = 1;
// }
const _text = 'void main() {\n  int x = 1;\n}\n';

Code _code() => Code(
  text: _text,
  highlighted: highlight.parse(_text, language: 'java'),
  language: java,
  namedSectionParser: const BracketsStartEndNamedSectionParser(),
);

void main() {
  group('Code.foldableBlockToHiddenRange', () {
    test('hides the content lines but keeps the opening and closing lines', () {
      // A real two-line block emitted by the highlighter for the same text.
      final code = _code();
      final block = code.foldableBlocks.firstWhere((b) => b.firstLine == 0);

      final range = code.foldableBlockToHiddenRange(block);

      expect(range.firstLine, 0);
      // Hides `  int x = 1;` (offsets 14..25) plus the newline before it.
      expect(range.start, 13);
      // Ends at the start of the closing `}` line, so the closer stays
      // visible. (`}` is at offset 26, so the range covers 13..26 — the two
      // newlines around the content line.)
      expect(range.end, 27);
    });

    test('a degenerate block falls back to hiding the closing line whole', () {
      // The parsers never emit a block whose only line *is* the closing line,
      // so this state is fabricated: `firstLine + 1` is the block's last line,
      // which is the closing `}`.
      //
      // Without the fallback the range would be empty (`start == end`) and
      // `HiddenRange` would assert.
      final code = _code();
      final degenerate = const FoldableBlock(
        firstLine: 1,
        lastLine: 2,
        type: FoldableBlockType.braces,
      );

      final range = code.foldableBlockToHiddenRange(degenerate);

      expect(range.start, 26, reason: 'after the opening content line');
      expect(
        range.end,
        27,
        reason: 'the closing line is hidden whole, through its newline',
      );
      expect(range.end, greaterThan(range.start));
    });
  });
}
