import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/src/code/code.dart';
import 'package:zuraffa_code_editor/src/named_sections/parsers/brackets_start_end.dart';

/// Backspacing the folded block's closer must delete only that brace.
///
/// The block `{`/`}` renders collapsed as `{}`; the closer is the first
/// visible character after the block's hidden range. Deleting it used to
/// expand the recovered diff range into the hidden range, silently
/// destroying the block's content along with the brace.
///
/// See <https://github.com/arrrrny/zuraffa_code_editor/issues/98>.
const _text = 'int a;\n{\nint b;\n}\n\n\nint c;\n';

Code _foldedCode() => Code(
  text: _text,
  highlighted: hl.highlight.parse(_text, language: 'java'),
  language: java,
  namedSectionParser: const BracketsStartEndNamedSectionParser(),
).foldedAt(1);

TextEditingValue _backspaced(String visible, int cursor) => TextEditingValue(
  text: visible.substring(0, cursor - 1) + visible.substring(cursor),
  selection: TextSelection.collapsed(offset: cursor - 1),
);

void main() {
  group('deleting the closer of a folded block', () {
    test('keeps the hidden content in the full text', () {
      final code = _foldedCode();
      final visible = code.visibleText;
      // The closer is the visible character right after the block's opener.
      final closer = visible.indexOf('}');
      expect(closer, greaterThan(0));

      final result = code.getEditResult(
        TextSelection.collapsed(offset: closer + 1),
        _backspaced(visible, closer + 1),
      );

      // Only the brace goes; `int b;` survives the edit, and the four
      // newlines that surrounded the brace stay.
      expect(result.fullTextAfter, 'int a;\n{\nint b;\n\n\n\nint c;\n');
    });

    test('an equivalent range deletion also keeps the hidden content', () {
      final code = _foldedCode();
      final visible = code.visibleText;
      final closer = visible.indexOf('}');

      final result = code.getEditResult(
        TextSelection(baseOffset: closer, extentOffset: closer + 1),
        TextEditingValue(
          text: visible.substring(0, closer) + visible.substring(closer + 1),
          selection: TextSelection.collapsed(offset: closer),
        ),
      );

      expect(result.fullTextAfter, 'int a;\n{\nint b;\n\n\n\nint c;\n');
    });

    test('deleting the closer and the following newline keeps the content', () {
      final code = _foldedCode();
      final visible = code.visibleText;
      final closer = visible.indexOf('}');

      final result = code.getEditResult(
        TextSelection(baseOffset: closer, extentOffset: closer + 2),
        TextEditingValue(
          text: visible.substring(0, closer) + visible.substring(closer + 2),
          selection: TextSelection.collapsed(offset: closer),
        ),
      );

      // The brace and its newline go; `int b;` and the remaining newlines
      // survive the edit.
      expect(result.fullTextAfter, 'int a;\n{\nint b;\n\n\nint c;\n');
    });
  });

  group('replacing the closer of a folded block', () {
    test('with longer text keeps the hidden content', () {
      final code = _foldedCode();
      final visible = code.visibleText;
      final closer = visible.indexOf('}');
      const replacement = '} else {';

      // Select the closer and type `} else {` over it. The visible text
      // grows, but the edit still starts by removing the closer, so the
      // body must survive like it does for a backspace.
      final result = code.getEditResult(
        TextSelection(baseOffset: closer, extentOffset: closer + 1),
        TextEditingValue(
          text:
              '${visible.substring(0, closer)}$replacement'
              '${visible.substring(closer + 1)}',
          selection: TextSelection.collapsed(
            offset: closer + replacement.length,
          ),
        ),
      );

      expect(result.fullTextAfter, 'int a;\n{\nint b;\n} else {\n\n\nint c;\n');
    });

    test('with a longer brace pair keeps the hidden content', () {
      final code = _foldedCode();
      final visible = code.visibleText;
      final closer = visible.indexOf('}');
      const replacement = '}}';

      final result = code.getEditResult(
        TextSelection(baseOffset: closer, extentOffset: closer + 1),
        TextEditingValue(
          text:
              '${visible.substring(0, closer)}$replacement'
              '${visible.substring(closer + 1)}',
          selection: TextSelection.collapsed(
            offset: closer + replacement.length,
          ),
        ),
      );

      expect(result.fullTextAfter, 'int a;\n{\nint b;\n}}\n\n\nint c;\n');
    });
  });

  group('inserting at the closer of a folded block', () {
    test('a pure insertion keeps the documented downstream recovery', () {
      final code = _foldedCode();
      final visible = code.visibleText;
      final closer = visible.indexOf('}');

      // Typing at the collapse point removes nothing, so the edit keeps
      // the downstream recovery and the text lands before the closer.
      final result = code.getEditResult(
        TextSelection.collapsed(offset: closer),
        TextEditingValue(
          text: '${visible.substring(0, closer)}x${visible.substring(closer)}',
          selection: TextSelection.collapsed(offset: closer + 1),
        ),
      );

      expect(result.fullTextAfter, 'int a;\n{x\nint b;\n}\n\n\nint c;\n');
    });
  });
}
