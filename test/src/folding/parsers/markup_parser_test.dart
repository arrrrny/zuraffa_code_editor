// ignore_for_file: avoid_private_typedef_functions
// ignore_for_file: prefer_const_constructors

import 'package:zuraffa_code_editor/src/code/code_lines.dart';
import 'package:zuraffa_code_editor/src/code_field/code_controller.dart';
import 'package:zuraffa_code_editor/src/folding/foldable_block.dart';
import 'package:zuraffa_code_editor/src/folding/foldable_block_type.dart';
import 'package:zuraffa_code_editor/src/folding/invalid_foldable_block.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/markup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/xml.dart';

typedef _Blocks = List<FoldableBlock>;
typedef _Invalid = List<InvalidFoldableBlock>;

/// Keeps the xml [Mode] in its own namespace so the tests do not fight over
/// the globally registered `xml` entry.
const _languageName = 'markup_test_language';

(_Blocks, _Invalid) _parse(String code) {
  highlight.registerLanguage(_languageName, xml);
  final highlighted = highlight.parse(code, language: _languageName);
  final parser = MarkupFoldableBlockParser();

  parser.parse(
    highlighted: highlighted,
    serviceCommentsSources: const <Object?>{},
    lines: CodeLines.empty,
  );

  return (parser.blocks, parser.invalidBlocks);
}

void _expect(
  String code, {
  required _Blocks blocks,
  _Invalid invalid = const [],
}) {
  final result = _parse(code);
  expect(result.$1, blocks);
  expect(result.$2, invalid);
}

FoldableBlock _block(int firstLine, int lastLine) => FoldableBlock(
  firstLine: firstLine,
  lastLine: lastLine,
  type: FoldableBlockType.markup,
);

InvalidFoldableBlock _invalidStart(int line) =>
    InvalidFoldableBlock(type: FoldableBlockType.markup, startLine: line);

InvalidFoldableBlock _invalidEnd(int line) =>
    InvalidFoldableBlock(type: FoldableBlockType.markup, endLine: line);

void main() {
  group('MarkupFoldableBlockParser', () {
    test('a nested element folds into one markup block', () {
      _expect(
        '<a>\n'
        '  <b>text</b>\n'
        '</a>\n',
        blocks: [_block(0, 2)],
      );
    });

    test('nested elements produce nested blocks', () {
      _expect(
        '<a>\n'
        '  <b>\n'
        '    text\n'
        '  </b>\n'
        '</a>\n',
        blocks: [_block(0, 4), _block(1, 3)],
      );
    });

    test('a self-closing element produces no block', () {
      _expect(
        '<br/>\n'
        '<img src="x" />\n',
        blocks: const [],
      );
    });

    test('the xml declaration and a comment produce no block', () {
      _expect(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- a comment\n'
        '     spanning lines -->\n',
        blocks: const [],
      );
    });

    test('an element on one line produces no block', () {
      _expect('<a>text</a>\n', blocks: const []);
    });

    test('an unclosed element is an invalid block', () {
      _expect(
        '<a>\n'
        '  text\n',
        blocks: const [],
        invalid: [_invalidStart(0)],
      );
    });

    test('a stray closing tag is an invalid block', () {
      _expect(
        'text\n'
        '</a>\n',
        blocks: const [],
        invalid: [_invalidEnd(1)],
      );
    });

    test('a < inside a comment or an attribute string is not markup', () {
      _expect(
        '<!-- <fake> -->\n'
        '<root a="<not-a-tag>" b="</also-not>">\n'
        '</root>\n',
        blocks: [_block(1, 2)],
      );
    });

    test('a document without markup produces nothing at all', () {
      _expect('just text\nand more text\n', blocks: const []);
    });
  });

  group('MarkupFoldableBlockParser through CodeController', () {
    test('an android layout gets a fold toggle for each nesting element', () {
      const layout =
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<!-- a comment -->\n'
          '<LinearLayout\n'
          '    xmlns:android="http://schemas.android.com/apk/res/android"\n'
          '    android:layout_width="match_parent">\n'
          '\n'
          '    <TextView\n'
          '        android:text="hello" />\n'
          '\n'
          '    <FrameLayout>\n'
          '      <Button android:id="@+id/go" />\n'
          '    </FrameLayout>\n'
          '\n'
          '</LinearLayout>\n';

      final code = CodeController(text: layout, language: xml).code;

      expect(code.foldableBlocks, [_block(2, 13), _block(9, 11)]);
      expect(code.invalidBlocks, const []);
    });
  });
}
