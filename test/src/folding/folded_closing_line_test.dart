import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

/// Regression test for the folded closing line.
///
/// Upstream `flutter_code_editor` hid a folded block through the END of its
/// last line, so a folded block rendered as a dangling opener with no closer —
/// `parsers: [` with no matching `],`. This test pins the fixed behaviour:
/// the closing line stays visible, the gutter line numbering is untouched,
/// and folding is lossless.
void main() {
  const config = 'final config = ScraperConfig(\n'
      '  clientType: HttpClientType.crawler,\n'
      '  parsers: [\n'
      '    ParserConfig(\n'
      '      kind: ParserType.jsonLd,\n'
      '    ),\n'
      '  ],\n'
      ');\n';

  CodeController createController() =>
      CodeController(text: config, language: java);

  group('Folded blocks keep their closing line visible.', () {
    test('A folded list shows the closing bracket', () {
      final controller = createController();

      controller.foldAt(2); // `  parsers: [`

      expect(controller.text, '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ],
);
''');
    });

    test('A folded method call shows the closing parenthesis', () {
      final controller = createController();

      controller.foldAt(3); // `    ParserConfig(`

      expect(controller.text, '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [
    ParserConfig(    ),
  ],
);
''');
    });

    test('The outermost block folds to a single line', () {
      final controller = createController();

      controller.foldAt(0);

      expect(controller.text, '''
final config = ScraperConfig();
''');
    });

    test('Gutter line numbering is unchanged by the fix', () {
      final folded = createController()..foldAt(2);
      final unfolded = createController();

      // Folding must not change how many lines the gutter renders, only hide
      // the lines that are merged into their opener.
      expect(
        folded.code.hiddenLineRanges.visibleLineNumbers.length,
        unfolded.code.lines.length - 4,
        reason: 'block 2..6 merges 4 lines into the opener',
      );

      // The opener keeps its own line number, so numbering stays aligned.
      expect(folded.code.hiddenLineRanges.cutLineIndexIfVisible(2), 2);
      // The lines inside the block are hidden.
      expect(folded.code.hiddenLineRanges.cutLineIndexIfVisible(4), isNull);
      // The line after the block is still the next visible row.
      expect(folded.code.hiddenLineRanges.cutLineIndexIfVisible(7), 3);
    });

    test('Folding and unfolding is lossless', () {
      final controller = createController();

      controller.foldAt(2);
      controller.foldAt(3);
      expect(controller.code.text, config, reason: 'full text survives folding');

      controller.unfoldAt(2);
      controller.unfoldAt(3);

      expect(controller.text, config);
      expect(controller.code.text, config);
      expect(controller.code.foldedBlocks, isEmpty);
    });

    test('Folding the outer block, then the inner one, stays consistent', () {
      final controller = createController();

      controller.foldAt(2); // `  parsers: [` folds 2..6
      controller.foldAt(3); // `    ParserConfig(` folds 3..5

      // Folding the outer block swallows the inner one, and the closing
      // bracket of the outer block is still shown.
      expect(controller.text, '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ],
);
''');
      expect(controller.code.text, config, reason: 'full text survives folding');

      controller.unfoldAt(2);
      controller.unfoldAt(3);
      expect(controller.text, config);
      expect(controller.code.foldedBlocks, isEmpty);
    });
  });
}
