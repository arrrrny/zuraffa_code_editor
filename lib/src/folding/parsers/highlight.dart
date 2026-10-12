import 'package:charcode/ascii.dart';
import 'package:collection/collection.dart';
import 'package:highlight/highlight_core.dart';

import '../../code/code_lines.dart';
import '../../highlight/keyword_semantics.dart';
import '../../highlight/node.dart';
import '../../highlight/node_classes.dart';
import '../foldable_block_type.dart';
import 'text.dart';

/// A parser for foldable blocks from highlight's [Result].
class HighlightFoldableBlockParser extends TextFoldableBlockParser {
  /// > 0 while inside a pair-character block that opened on a line with
  /// import semantics.
  ///
  /// Such a block belongs to the import statement, not to the code, so the
  /// absorption decision and the closing line's semantics are handled here,
  /// in the parser that owns the pair characters. Unlike the per-line flags
  /// of [TextFoldableBlockParser] this state must outlive the lines it spans,
  /// so it is not cleared between lines.
  int _importPairBlockDepth = 0;

  void enterImportPairBlock() => _importPairBlockDepth++;

  void exitImportPairBlock() => _importPairBlockDepth--;

  /// Whether the parser is inside a pair-character block absorbed by a
  /// multi-line import statement.
  bool get inImportPairBlock => _importPairBlockDepth > 0;

  /// Whether non-whitespace content other than the import keyword was
  /// seen on the current line before the current pair character.
  ///
  /// This distinguishes Scala's selective import `import users.{ ... }`,
  /// where the braces are part of the statement and are absorbed, from
  /// JS/TS `import { ... } from 'module'`, where the braces are the
  /// import list syntax and keep their own fold.
  bool _foundImportQualifier = false;

  @override
  void parse({
    required Result highlighted,
    required Set<Object?> serviceCommentsSources,
    CodeLines lines = CodeLines.empty,
  }) {
    if (highlighted.nodes != null) {
      _processNodes(highlighted.nodes!, serviceCommentsSources);
    }

    submitCurrentLine(); // In case the last one did not end with '\n'.
    finalize();
  }

  void _processNodes(List<Node> nodes, Set<Object?> serviceCommentsSources) {
    for (final node in nodes) {
      _processNode(node, serviceCommentsSources);
    }
  }

  void _processNode(Node node, Set<Object?> serviceCommentsSources) {
    switch (node.className) {
      case NodeClasses.comment:
        _processComment(node, serviceCommentsSources);
        break;

      case NodeClasses.keyword:
        _processKeyword(node);
        break;

      case NodeClasses.string:
        _processString(node);
        break;

      default:
        _processDefault(node, serviceCommentsSources);
    }
  }

  void _processComment(Node node, Set<Object?> serviceCommentsSources) {
    final newlineCount = node.getNewlineCount();

    if (foundNonWhitespace && newlineCount == 0) {
      return;
    }

    if (serviceCommentsSources.contains(node)) {
      return;
    }

    if (newlineCount == 0) {
      setFoundSingleLineComment();
      return;
    }

    startBlock(lineIndex, FoldableBlockType.multilineComment);

    for (int i = 0; i < newlineCount; i++) {
      setFoundMultilineComment();
      submitCurrentLine();
      addToLineIndex(1);
    }

    endBlock(lineIndex, FoldableBlockType.multilineComment);
  }

  void _processKeyword(Node node) {
    final child = node.children?.firstOrNull;
    if (child == null) {
      return;
    }

    final semantics = node.keywordSemantics;

    switch (semantics) {
      case KeywordSemantics.import:
        setFoundImport();
        break;
      case KeywordSemantics.possibleImport:
        setFoundPossibleImport();
        break;
      case null:
        setFoundImportTerminator();
        break;
    }
  }

  void _processString(Node node) {
    final newlineCount = node.getNewlineCount();

    setFoundNonWhitespace();
    if (newlineCount > 0) {
      setFoundImportTerminator();
      submitCurrentLine();
      clearLineFlags();
    }

    addToLineIndex(newlineCount);
  }

  void _processDefault(Node node, Set<Object?> serviceCommentsSources) {
    _processDefaultValue(node);

    if (node.children != null) {
      _processNodes(node.children!, serviceCommentsSources);
    }
  }

  /// Except: comment, keyword, string
  void _processDefaultValue(Node node) {
    final value = node.value;
    if (value == null) {
      return;
    }

    for (final code in value.runes) {
      switch (code) {
        case $space:
        case $tab:
        case $cr:
        case $lf:
          break;

        case $openParenthesis: // (
        case $closeParenthesis: // )
        case $openBracket: // [
        case $closeBracket: // ]
        case $openBrace: // {
        case $closeBrace: // }
          setFoundNonWhitespace();
          break;

        default:
          setFoundNonWhitespace();
          _foundImportQualifier = true;
      }

      switch (code) {
        case $lf: // Newline
          submitCurrentLine();
          clearLineFlags();
          addToLineIndex(1);
          break;

        case $openParenthesis: // (
          _startPairOrBlock(lineIndex, FoldableBlockType.parentheses);
          break;

        case $closeParenthesis: // )
          _endPairOrBlock(lineIndex, FoldableBlockType.parentheses);
          break;

        case $openBracket: // [
          _startPairOrBlock(lineIndex, FoldableBlockType.brackets);
          break;

        case $closeBracket: // ]
          _endPairOrBlock(lineIndex, FoldableBlockType.brackets);
          break;

        case $openBrace: // {
          _startPairOrBlock(lineIndex, FoldableBlockType.braces);
          break;

        case $closeBrace: // }
          _endPairOrBlock(lineIndex, FoldableBlockType.braces);
          break;
      }
    }
  }

  /// Opens [type] unless the pair character belongs to a multi-line import.
  ///
  /// Only a brace opened on an import line after a qualifier is absorbed:
  /// Scala's selective import `import users.{ User, UserPreferences }`
  /// selects members, so the braces are part of the statement. JS/TS
  /// `import { ... } from 'module'` has no qualifier — its braces are the
  /// import list syntax and keep their own fold, pinned by the JS/TS tests.
  /// A parenthesized group such as Go's `import ( ... )` is a clause users
  /// fold on its own — pinned by the Go tests. Pair characters inside an
  /// absorbed block are absorbed too.
  void _startPairOrBlock(int line, FoldableBlockType type) {
    final absorb =
        inImportPairBlock ||
        (foundImport &&
            type == FoldableBlockType.braces &&
            _foundImportQualifier);

    if (absorb) {
      enterImportPairBlock();
      return;
    }

    startBlock(line, type);
  }

  /// Closes [type] unless the pair character closes an absorbed import block.
  ///
  /// The closing line is submitted as an import line, so the imports sequence
  /// extends through it.
  void _endPairOrBlock(int line, FoldableBlockType type) {
    if (inImportPairBlock) {
      exitImportPairBlock();
      setFoundPossibleImport();
      return;
    }

    endBlock(line, type);
  }

  @override
  void clearLineFlags() {
    super.clearLineFlags();
    _foundImportQualifier = false;
  }

  @override
  void onImportTerminatorLine() {
    if (inImportPairBlock) {
      // A keyword line inside the import's braces means the statement was
      // abandoned — the file is malformed from here on. Stop absorbing
      // pair characters so the rest of the file folds normally.
      _importPairBlockDepth = 0;
    }
  }
}
