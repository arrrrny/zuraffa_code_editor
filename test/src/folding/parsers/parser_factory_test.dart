import 'package:zuraffa_code_editor/src/folding/parsers/fallback.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/highlight.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/indent.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/java.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/parser_factory.dart';
import 'package:zuraffa_code_editor/src/folding/parsers/python.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/yaml.dart';

void main() {
  group('FoldableBlockParserFactory', () {
    test('python gets the indent parser', () {
      expect(
        FoldableBlockParserFactory.provideParser(python),
        isA<PythonFoldableBlockParser>(),
      );
    });

    test('java gets the java parser', () {
      expect(
        FoldableBlockParserFactory.provideParser(java),
        isA<JavaFoldableBlockParser>(),
      );
    });

    test('yaml falls back to the plain indent parser', () {
      // YAML has no braces to count, so its blocks come from indentation
      // alone and the generic indent parser is the right tool.
      expect(
        FoldableBlockParserFactory.provideParser(yaml),
        isA<IndentFoldableBlockParser>(),
      );
    });

    test('anything else gets the highlight-driven parser', () {
      final parser = FoldableBlockParserFactory.provideParser(Mode());

      expect(parser, isA<HighlightFoldableBlockParser>());
      expect(parser, isNot(isA<FallbackFoldableBlockParser>()));
    });
  });
}
