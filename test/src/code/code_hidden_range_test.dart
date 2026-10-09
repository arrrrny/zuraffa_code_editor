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
      // visible. (`}` is at offset 27, and the end is exclusive, so the range
      // covers 13..26 — the two newlines around the content line, plus the
      // content between them.)
      expect(range.end, 27);
    });

    test('a truly degenerate block still produces an empty range', () {
      // The parsers never emit a block whose only line *is* the closing line,
      // so this state is fabricated: `lastLine == firstLine` is the only shape
      // satisfying `endOfRange <= startOfRange`, and that is what takes the
      // degenerate-block fallback.
      //
      // The fallback recomputes `_upstreamEndOfRange(lastLine)` — the newline
      // index of the same line the range already ends at — so the range stays
      // empty and `HiddenRange` still asserts. This pins that honestly: the
      // fallback executes but does not prevent the assert for this shape.
      final code = _code();

      expect(
        () => code.foldableBlockToHiddenRange(
          const FoldableBlock(
            firstLine: 2,
            lastLine: 2,
            type: FoldableBlockType.braces,
          ),
        ),
        throwsA(const TypeMatcher<AssertionError>()),
      );
    });
  });
}
