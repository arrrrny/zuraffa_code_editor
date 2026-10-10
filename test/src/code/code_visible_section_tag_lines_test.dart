import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import 'package:zuraffa_code_editor/src/code/code.dart';
import 'package:zuraffa_code_editor/src/named_sections/parsers/brackets_start_end.dart';

/// A visible section's two tag lines are scaffolding: the `[START name]` and
/// `[END name]` comments hide themselves, but the whitespace before them and
/// the line break after them used to survive in the presented text, so the
/// section rendered with a blank line before and after its contents.
///
/// These pin the cut, and the shapes that must not be cut.
Code _code(String text, {Set<String>? visibleSectionNames}) => Code(
  text: text,
  language: java,
  namedSectionParser: const BracketsStartEndNamedSectionParser(),
  visibleSectionNames: visibleSectionNames ?? const {},
);

void main() {
  group('Visible section tag lines', () {
    test('the tag lines are cut from the presented section', () {
      const text = 'before1\n\n// [START s]\n  int x;\n// [END s]\n\nafter1\n';

      final code = _code(text, visibleSectionNames: {'s'});

      // The blank lines *around* the section were already cut by the
      // beginning/ending ranges; what is left after this is the section's
      // contents, flush.
      expect(code.visibleText, '  int x;\n');
      expect(code.text, text);
    });

    test('the cut tag lines drop out of the visible line numbers', () {
      const text = 'before1\n\n// [START s]\n  int x;\n// [END s]\n\nafter1\n';

      final code = _code(text, visibleSectionNames: {'s'});

      // The content line keeps its document line number, and the trailing
      // empty document line — the row the caret rests on after the content —
      // keeps its own. The two tag lines have no visible row left to label,
      // so they are gone from the numbering.
      expect(code.hiddenLineRanges.visibleLineNumbers.toList(), [3, 7]);

      // The numbering must still account for every row the editor renders.
      expect(
        code.visibleText.split('\n').length,
        code.hiddenLineRanges.visibleLineNumbers.length,
      );
    });

    test('a tag line that only holds the tag is cut, code and all', () {
      const text = '//   [START s]\n  int x;\n//   [END s]\n';

      final code = _code(text, visibleSectionNames: {'s'});

      expect(code.visibleText, '  int x;\n');
    });

    test('a tag sharing its line with code is not cut', () {
      const text = 'class A {// [START s]\n  int x;\n}// [END s]\n';

      final code = _code(text, visibleSectionNames: {'s'});

      // The code before the comment belongs to the section: the line stays,
      // and only the comment itself is hidden, as before.
      expect(code.visibleText, 'class A {\n  int x;\n}\n');
    });

    test('only the visible section\'s own tags are cut', () {
      const text =
          'class A {// [START whole]\n'
          '  // [START inner]\n'
          '  int x;\n'
          '  // [END inner]\n'
          '}// [END whole]\n';

      final code = _code(text, visibleSectionNames: {'whole'});

      // `whole`'s own tags sit on code lines and are not cut. The inner
      // section's tag lines are part of `whole`'s contents and keep their
      // remnants, exactly as they render today.
      expect(code.visibleText, 'class A {\n  \n  int x;\n  \n}\n');
    });

    test('a section with no start tag cuts its end tag', () {
      const text = 'class A {\n  int x;\n// [END s]\n';

      final code = _code(text, visibleSectionNames: {'s'});

      expect(code.visibleText, 'class A {\n  int x;\n');
    });

    test('the start tag is cut at the very top of the document', () {
      const text = '// [START s]\n  int x;\n// [END s]\n';

      final code = _code(text, visibleSectionNames: {'s'});

      expect(code.visibleText, '  int x;\n');
    });

    test('an end tag with no line break after it keeps its line', () {
      const text = 'before\n// [START s]\n  int x;\n// [END s]';

      final code = _code(text, visibleSectionNames: {'s'});

      // There is no trailing newline to cut, so the last line keeps the
      // remnant the comment range always left.
      expect(code.visibleText, '  int x;\n');
    });

    test('an empty section presents nothing', () {
      const text = '\n// [START s]\n// [END s]\n';

      final code = _code(text, visibleSectionNames: {'s'});

      expect(code.visibleText, '');
    });

    test('a document without visible sections is untouched', () {
      const text = '// readonly\n  int x;\n';

      final code = _code(text);

      // Read-only comments hide themselves only; presentation mode is what
      // cuts the rest of the line, and there is no visible section here.
      expect(code.visibleText, '\n  int x;\n');
    });

    test('the cut survives a selection round trip', () {
      const text = 'before1\n\n// [START s]\n  int x;\n// [END s]\n\nafter1\n';

      final code = _code(text, visibleSectionNames: {'s'});

      // The cut moves every character after it, so the visible -> full ->
      // visible mapping has to still round-trip: a selection spanning the
      // whole presented section recovers to a selection of the full
      // document that cuts back to the very same visible selection.
      final visible = TextSelection(
        baseOffset: 0,
        extentOffset: code.visibleText.length,
      );

      final recovered = code.hiddenRanges.recoverSelection(visible);

      expect(code.hiddenRanges.cutSelection(recovered), visible);
    });
  });
}
