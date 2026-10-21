import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:tuple/tuple.dart';

import '../../single_line_comments/parser/single_line_comments.dart';
import 'abstract.dart';
import 'fallback.dart';
import 'highlight.dart';
import 'indent.dart';
import 'java.dart';
import 'markup.dart';
import 'markup_fallback.dart';
import 'python.dart';

class FoldableBlockParserFactory {
  static AbstractFoldableBlockParser provideParser(Mode mode) {
    if (mode == python) {
      return PythonFoldableBlockParser();
    }
    if (mode == java) {
      return JavaFoldableBlockParser();
    }

    if (mode == yaml) {
      return IndentFoldableBlockParser();
    }

    if (mode == xml) {
      return MarkupFoldableBlockParser();
    }

    return HighlightFoldableBlockParser();
  }

  /// A parser that finds the foldable blocks in the raw text.
  ///
  /// The parsers of [provideParser] read the structure out of the highlight's
  /// node tree, and there is no node tree without a highlight. These read the
  /// text instead, which is what the java and the python parsers already fall
  /// back to when the document is not highlighted.
  static AbstractFoldableBlockParser provideTextParser(Mode mode) {
    if (mode == python) {
      return PythonFoldableBlockParser();
    }
    if (mode == java) {
      return JavaFoldableBlockParser();
    }

    if (mode == yaml) {
      return IndentFoldableBlockParser();
    }

    if (mode == xml) {
      return MarkupFallbackFoldableBlockParser();
    }

    return FallbackFoldableBlockParser(
      importPrefixes: const ['import ', 'package '],
      multilineCommentSequences: const [Tuple2('/*', '*/')],
      singleLineCommentSequences: SingleLineComments.byMode[mode] ?? const [],
    );
  }
}
