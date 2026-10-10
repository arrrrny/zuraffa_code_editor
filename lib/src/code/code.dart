import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:highlight/highlight_core.dart';

import '../../src/highlight/result.dart';
import '../code_field/text_editing_value.dart';
import '../folding/foldable_block.dart';
import '../folding/foldable_block_matcher.dart';
import '../folding/invalid_foldable_block.dart';
import '../folding/parsers/parser_factory.dart';
import '../hidden_ranges/hidden_line_ranges.dart';
import '../hidden_ranges/hidden_line_ranges_builder.dart';
import '../hidden_ranges/hidden_range.dart';
import '../hidden_ranges/hidden_ranges.dart';
import '../hidden_ranges/hidden_ranges_builder.dart';
import '../named_sections/named_section.dart';
import '../named_sections/parsers/abstract.dart';
import '../service_comment_filter/service_comment_filter.dart';
import '../single_line_comments/parser/single_line_comment_parser.dart';
import '../single_line_comments/parser/single_line_comments.dart';
import '../single_line_comments/single_line_comment.dart';
import 'code_edit_result.dart';
import 'code_line.dart';
import 'code_lines.dart';
import 'code_lines_builder.dart';
import 'map.dart';
import 'string.dart';
import 'text_range.dart';

class Code {
  final String text;
  final List<FoldableBlock> foldableBlocks;
  final Set<FoldableBlock> foldedBlocks;
  final HiddenLineRanges hiddenLineRanges;
  final HiddenRanges hiddenRanges;
  final Result? highlighted;
  final List<InvalidFoldableBlock> invalidBlocks;
  final CodeLines lines;
  final Map<String, NamedSection> namedSections;
  final Result? visibleHighlighted;
  final String visibleText;
  final Set<String> visibleSectionNames;

  final HiddenRangesBuilder _hiddenRangesBuilder;

  factory Code({
    required String text,
    Result? highlighted,
    Mode? language,
    AbstractNamedSectionParser? namedSectionParser,
    Set<String> readOnlySectionNames = const {},
    Set<String> visibleSectionNames = const {},
  }) {
    final sequences = SingleLineComments.byMode[language] ?? [];

    final commentParser = SingleLineCommentParser.parseHighlighted(
      text: text,
      highlighted: highlighted,
      singleLineCommentSequences: sequences,
    );

    final serviceComments = ServiceCommentFilter.filter(
      commentParser.comments,
      namedSectionParser: namedSectionParser,
    );

    final serviceCommentsNodesSet = serviceComments.sources;

    final List<FoldableBlock> foldableBlocks;
    var invalidBlocks = List<InvalidFoldableBlock>.empty();

    final lines = CodeLinesBuilder.textToCodeLines(
      text: text,
      readonlyCommentsByLine: commentParser.getIfReadonlyCommentByLine(),
    );

    if (highlighted == null || language == null) {
      foldableBlocks = const [];
    } else {
      final parser = FoldableBlockParserFactory.provideParser(language);

      parser.parse(
        highlighted: highlighted,
        serviceCommentsSources: serviceCommentsNodesSet,
        lines: lines,
      );

      foldableBlocks = parser.blocks;
      invalidBlocks = parser.invalidBlocks;
    }

    final sections =
        namedSectionParser?.parse(singleLineComments: commentParser.comments) ??
        const [];
    final sectionsMap = {for (final s in sections) s.name: s};

    final isCodeReadonly = visibleSectionNames.isNotEmpty;
    if (isCodeReadonly) {
      _makeCodeReadonly(lines: lines.lines);
    } else {
      _applyNamedSectionsToLines(
        lines: lines.lines,
        sections: sectionsMap,
        readOnlySectionNames: readOnlySectionNames,
      );
    }

    final visibleSectionsHiddenRanges = _visibleSectionsToHiddenRanges(
      visibleSectionNames,
      sectionsMap,
      lines,
    );

    final commentsHiddenRanges = _commentsToHiddenRanges(serviceComments);

    final hiddenRangesBuilder = HiddenRangesBuilder.fromMaps({
      String: visibleSectionsHiddenRanges,
      int: commentsHiddenRanges,
    }, textLength: text.length);
    final hiddenRanges = hiddenRangesBuilder.ranges;

    final hiddenLineRangesBuilder = HiddenLineRangesBuilder(
      codeLines: lines,
      hiddenRanges: hiddenRanges,
    );

    return Code._(
      text: text,
      foldableBlocks: foldableBlocks,
      foldedBlocks: {},
      hiddenLineRanges: hiddenLineRangesBuilder.hiddenLineRanges,
      hiddenRanges: hiddenRanges,
      hiddenRangesBuilder: hiddenRangesBuilder,
      highlighted: highlighted,
      invalidBlocks: invalidBlocks,
      lines: lines,
      namedSections: sectionsMap,
      visibleHighlighted: hiddenRanges
          .cutHighlighted(highlighted)
          ?.splitLines(),
      visibleText: hiddenRanges.cutString(text),
      visibleSectionNames: visibleSectionNames,
    );
  }

  const Code._({
    required this.text,
    required this.foldableBlocks,
    required this.foldedBlocks,
    required this.hiddenLineRanges,
    required this.hiddenRanges,
    required HiddenRangesBuilder hiddenRangesBuilder,
    required this.highlighted,
    this.invalidBlocks = const [],
    required this.lines,
    required this.namedSections,
    required this.visibleHighlighted,
    required this.visibleText,
    required this.visibleSectionNames,
  }) : _hiddenRangesBuilder = hiddenRangesBuilder;

  static const empty = Code._(
    text: '',
    foldableBlocks: [],
    foldedBlocks: {},
    hiddenLineRanges: HiddenLineRanges.empty,
    hiddenRanges: HiddenRanges.empty,
    hiddenRangesBuilder: HiddenRangesBuilder.empty,
    highlighted: null,
    lines: CodeLines.empty,
    namedSections: {},
    visibleHighlighted: null,
    visibleText: '',
    visibleSectionNames: {},
  );

  static void _makeCodeReadonly({required List<CodeLine> lines}) {
    for (int i = 0; i < lines.length; i++) {
      lines[i] = lines[i].copyWith(isReadOnly: true);
    }
  }

  static void _applyNamedSectionsToLines({
    required List<CodeLine> lines,
    required Map<String, NamedSection> sections,
    required Set<String> readOnlySectionNames,
  }) {
    for (final name in readOnlySectionNames) {
      final section = sections[name];

      if (section == null) {
        continue;
      }

      final lastLineIndex = section.lastLine ?? lines.length - 1;

      for (int i = section.firstLine; i <= lastLineIndex; i++) {
        lines[i] = lines[i].copyWith(isReadOnly: true);
      }
    }
  }

  ///Assumes that there is only one visible section.
  ///If there are more than one, the first one will be used,
  ///and the rest will be ignored.
  static Map<String, HiddenRange> _visibleSectionsToHiddenRanges(
    Set<String> names,
    Map<String, NamedSection> namedSections,
    CodeLines lines,
  ) {
    final section = namedSections.getByKeys(names).firstOrNull;

    final result = <String, HiddenRange>{};

    if (section == null) {
      if (lines.lines.last.textRange.end > 0 && names.isNotEmpty) {
        result['beginning'] = HiddenRange(
          0,
          lines.lines.last.textRange.end,
          firstLine: 0,
          lastLine: lines.lines.length - 1,
          wholeFirstLine: true,
        );
      }
      return result;
    }

    final startLine = lines.lines[section.firstLine];
    if (startLine.textRange.start > 0) {
      result['beginning'] = HiddenRange(
        0,
        startLine.textRange.start,
        firstLine: 0,
        lastLine: section.firstLine - 1,
        wholeFirstLine: true,
      );
    }
    final lastLine = section.lastLine;
    if (lastLine != null && lastLine < lines.lines.length - 1) {
      final start = lines.lines[lastLine].textRange.end;
      final end = lines.lines.last.textRange.end;

      // Can be equal if the last line has no \n.
      if (end > start) {
        result['ending'] = HiddenRange(
          start,
          end,
          firstLine: lastLine,
          lastLine: lines.lines.length - 1,
          wholeFirstLine: false,
        );
      }
    }
    return result;
  }

  static Map<int, HiddenRange> _commentsToHiddenRanges(
    Iterable<SingleLineComment> comments,
  ) {
    return <int, HiddenRange>{
      for (final comment in comments)
        comment.characterIndex: HiddenRange(
          comment.characterIndex,
          comment.characterIndex + comment.outerContent.length,
          firstLine: comment.lineIndex,
          lastLine: comment.lineIndex,
          wholeFirstLine: false,
        ),
    };
  }

  /// Returns whether the current selection has any read-only part.
  bool isReadOnlySelected(TextRange range) {
    if (range.start == -1 && range.end == -1) {
      return false; // Empty selection.
    }

    final startChar = range.normalized.start;
    final endChar = range.normalized.end;

    return isReadOnlyInLineRange(
      TextRange(
        start: lines.characterIndexToLineIndex(startChar),
        end: lines.characterIndexToLineIndex(endChar),
      ),
    );
  }

  /// Returns whether any of the lines of this range is read-only.
  bool isReadOnlyInLineRange(TextRange lineRange) {
    for (int line = lineRange.start; line <= lineRange.end; line++) {
      if (lines.lines[line].isReadOnly) {
        return true;
      }
    }

    return false;
  }

  /// Returns the resulting full text if a given visible text edit is applied.
  ///
  /// The text in [visibleAfter] should be different from the [visibleText]
  /// otherwise the selected text is still considered to change.
  /// This is for the purpose of speed because this method is only supposed
  /// to be called during a change.
  ///
  /// [oldSelection] is the [TextSelection] before the edit.
  /// It is considered in a few special cases if the edit is around
  /// the selection. This is required to disambiguate
  /// edits that can otherwise lead to erroneous actions on hidden ranges.
  ///
  /// Outside of those special cases the [visibleAfter] is just diffed
  /// against [visibleText]. This changed region may be ambiguous.
  /// In this case the change is attributed upstream meaning the first
  /// possible region is considered to hold the change.
  CodeEditResult getEditResult(
    TextSelection oldSelection,
    TextEditingValue visibleAfter,
  ) {
    // An IME may report selections that are out of range for the text
    // they are applied to while a composition is being replaced.
    final clampedOldSelection = _clampSelection(
      oldSelection,
      visibleText.length,
    );
    final clampedVisibleAfter = visibleAfter.copyWith(
      selection: _clampSelection(
        visibleAfter.selection,
        visibleAfter.text.length,
      ),
    );

    final visibleRangeAfter =
        clampedVisibleAfter.getChangedRange(
          TextEditingValue(text: visibleText, selection: clampedOldSelection),
        ) ??
        clampedVisibleAfter.text.getChangedRange(
          visibleText,
          attributeChangeTo: TextAffinity.upstream,
        );

    if (visibleRangeAfter.start == -1 && visibleRangeAfter.end == -1) {
      return CodeEditResult(fullTextAfter: text, linesChanged: TextRange.empty);
    }

    // Recover what exactly was the full old text that was replaced
    // with the new one. For this, inspect the start and end points
    // of the changed part in the old visibleText.
    // If any hidden ranges are collapsed at those points,
    // the trick is to correctly replace them or to correctly preserve them.
    final rangeBefore = TextRange(
      // `end` is responsible for deciding between these two cases when the user
      // entered some text at the point with a hidden range:
      //     text we are adding at the beginning of this line// [START section1]
      //     // [START section1]text we are adding at the beginning of this line
      // We do not want to add that text to the comment and its hidden range.
      // So we must place all hidden ranges collapsed at the end of the diff
      // *after* that diff:
      end: hiddenRanges.recoverPosition(
        visibleText.length - visibleAfter.text.length + visibleRangeAfter.end,
        placeHiddenRanges: TextAffinity.downstream,
      ),

      // If we are inserting (and the old changed part is empty),
      // then using the same `placeHiddenRanges` is straightforward.
      //
      // However, this is also the only option for a non-empty old changed range
      // with a hidden range collapsed at its start. Otherwise we would
      // append to that comment, and the new text will not be visible.
      // Using `TextAffinity.downstream` effectively deletes any such hidden
      // range because it falls into the range of replacement.
      // We may want to reconsider this if we support terminatable hidden range
      // comments like /* ... */ that do not acquire all text to the
      // end of the string.
      start: hiddenRanges.recoverPosition(
        visibleRangeAfter.start,
        placeHiddenRanges: TextAffinity.downstream,
      ),
    );

    final firstChangedLine = lines.characterIndexToLineIndex(rangeBefore.start);
    final lastChangedLine = lines.characterIndexToLineIndex(rangeBefore.end);

    // If there is any folded block that is going to be removed
    // because of `backspace` or `delete`, return unchanged text.
    if (oldSelection.isCollapsed &&
        visibleAfter.text.length == visibleText.length - 1 &&
        foldedBlocks.any(
          (block) =>
              block.lastLine >= firstChangedLine &&
              block.lastLine < lastChangedLine,
        )) {
      return CodeEditResult(
        fullTextAfter: text,
        linesChanged: const TextRange(start: 0, end: 0),
      );
    }

    final fullTextAfter =
        rangeBefore.textBefore(text) +
        visibleRangeAfter.textInside(clampedVisibleAfter.text) +
        rangeBefore.textAfter(text);

    // The line at [start] has changed for sure.
    // The line at [end - 1] has changed if [end > start].
    // Additionally, the line at [end] has changed if two strings were glued:
    //  - (1) The last old char was '\n' AND
    //  - (2) The char before [start] is not '\n'.
    // We don't need to check (1) because otherwise [end] and [end - 1]
    // are on the same line.
    final lastChar =
        rangeBefore.end -
        ((rangeBefore.start == 0 || text[rangeBefore.start - 1] == '\n')
            ? 1
            : 0);

    final linesChanged = TextRange(
      start: lines.characterIndexToLineIndex(rangeBefore.start),
      end: lines.characterIndexToLineIndex(max(lastChar, rangeBefore.start)),
    );

    return CodeEditResult(
      fullTextAfter: fullTextAfter,
      linesChanged: linesChanged,
    );
  }

  Code foldedAt(int line) {
    final block = _getFoldableBlockByStartLine(line);
    if (block == null || foldedBlocks.contains(block)) {
      // ignore: avoid_returning_this
      return this;
    }

    final hiddenRange = foldableBlockToHiddenRange(block);
    final newHiddenRangesBuilder = _hiddenRangesBuilder.copyWithRange(
      block,
      hiddenRange,
    );

    return _copyWithFolding(
      foldedBlocks: {...foldedBlocks, block},
      hiddenRangesBuilder: newHiddenRangesBuilder,
    );
  }

  Code unfoldedAt(int line) {
    final block = _getFoldableBlockByStartLine(line);
    if (block == null || !foldedBlocks.contains(block)) {
      // ignore: avoid_returning_this
      return this;
    }

    return _copyWithFolding(
      foldedBlocks: {...foldedBlocks}..remove(block),
      hiddenRangesBuilder: _hiddenRangesBuilder.copyWithoutRange(block),
    );
  }

  FoldableBlock? _getFoldableBlockByStartLine(int line) {
    // It is important that we try to take a block from folded blocks first
    // and only then from foldable blocks.
    return foldedBlocks.firstWhereOrNull((block) => block.firstLine == line) ??
        foldableBlocks.firstWhereOrNull((block) => block.firstLine == line);
  }

  /// Whether the last line of a foldable block is a *closing* line — `)`,
  /// `]`, `}`, `);`, `},` … — rather than a line of the block's content.
  ///
  /// Folding must leave a closing line on screen (see
  /// [foldableBlockToHiddenRange]), but it must hide content lines whole.
  static bool _isClosingLine(CodeLine line) {
    final text = line.text.trimLeft();
    return text.startsWith(')') || text.startsWith(']') || text.startsWith('}');
  }

  HiddenRange foldableBlockToHiddenRange(FoldableBlock block) {
    final firstLine = lines.lines[block.firstLine + 1]; //Keep 1st line visible.
    final lastLine = lines.lines[block.lastLine];

    // Includes '\n' before.
    final startOfRange = firstLine.textRange.start - 1;

    // Ends at the START of the block's last line when that line is a closing
    // line, so the closer stays visible when folded. Hiding through the end
    // of the last line made `parsers: [` fold to a lone opening bracket with
    // no matching closer, which reads as broken code. Ending at the start
    // still resolves — via `characterIndexToLineIndex` — to `block.lastLine`,
    // exactly as the end does, so the derived `LineNumberingBreakpoint`s, the
    // gutter numbering and the fold-toggle rows are bit-for-bit unchanged.
    //
    // A content line (the tail of a `//` comment block, a continued argument)
    // must be hidden whole, as upstream does. Stopping at its start would
    // delete only the preceding newline and glue it onto the line above:
    // `// first// second`.
    var endOfRange = _isClosingLine(lastLine)
        ? lastLine.textRange.start
        : _upstreamEndOfRange(lastLine);

    if (endOfRange <= startOfRange) {
      // Degenerate block (lastLine == firstLine, so there is nothing between
      // the kept line and the closing line). Fall back to hiding the closing
      // line entirely, exactly as upstream does, to avoid an empty range.
      endOfRange = _upstreamEndOfRange(lastLine);
    }

    // Normally the closer shares a row with the opener, exactly as upstream
    // does: `parsers: [` folds to `parsers: [  ],`. That is fine while the
    // closing line only closes this block.
    //
    // But when the closing line also opens the following foldable block —
    // `}void main(){` closes `factorial` and opens `main` on the same line —
    // the closer needs a row of its own. That row is where the following
    // block hangs its fold toggle, and it is the only row that can carry the
    // line number of the block's own start. Gluing the two rows together
    // loses both, so folding the block above hides the start of the one below
    // it (akvelon/flutter-code-editor#213).
    //
    // Ending the range just before the closing line still leaves the closer's
    // text on screen: the newline that ended the previous content line falls
    // outside the range and becomes the row break the closer needs.
    if (_isClosingLine(lastLine) && _startsAnotherFoldableBlock(block)) {
      final closerOnItsOwnRow = lastLine.textRange.start - 1;
      if (closerOnItsOwnRow > startOfRange) {
        endOfRange = closerOnItsOwnRow;
      }
    }

    return HiddenRange(
      startOfRange,
      endOfRange,
      firstLine: block.firstLine,
      lastLine: block.lastLine,
      wholeFirstLine: false, // Some characters of the first line are visible.
    );
  }

  /// Whether a foldable block other than [block] starts on the very line
  /// [block] ends on.
  ///
  /// This is the "another block at the end of the first" case: the last line
  /// closes this block and opens the next one at the same time.
  bool _startsAnotherFoldableBlock(FoldableBlock block) => foldableBlocks.any(
    (other) => !other.isSameLines(block) && other.firstLine == block.lastLine,
  );

  /// The hidden range end upstream uses: the end of [line] excluding its
  /// trailing newline.
  static int _upstreamEndOfRange(CodeLine line) {
    var end = line.textRange.end - 1;
    if (line.text[line.text.length - 1] != '\n') {
      end++;
    }
    return end;
  }

  /// Folds this code at the same blocks as the [oldCode] is.
  Code foldedAs(Code oldCode) {
    final matcher = FoldableBlockMatcher(
      oldLines: oldCode.lines.lines,
      newBlocks: foldableBlocks,
      newLines: lines.lines,
      oldFoldedBlocks: oldCode.foldedBlocks,
    );

    final newHiddenRangesBuilder = _hiddenRangesBuilder.copyMergingSourceMap({
      FoldableBlock: {
        for (final block in matcher.newFoldedBlocks)
          block: foldableBlockToHiddenRange(block),
      },
    });

    return _copyWithFolding(
      foldedBlocks: matcher.newFoldedBlocks,
      hiddenRangesBuilder: newHiddenRangesBuilder,
    );
  }

  Code _copyWithFolding({
    required Set<FoldableBlock> foldedBlocks,
    required HiddenRangesBuilder hiddenRangesBuilder,
  }) {
    final hiddenRanges = hiddenRangesBuilder.ranges;

    final hiddenLineRangesBuilder = HiddenLineRangesBuilder(
      codeLines: lines,
      hiddenRanges: hiddenRanges,
    );

    return Code._(
      text: text,
      foldableBlocks: foldableBlocks,
      foldedBlocks: foldedBlocks,
      hiddenLineRanges: hiddenLineRangesBuilder.hiddenLineRanges,
      hiddenRanges: hiddenRanges,
      hiddenRangesBuilder: hiddenRangesBuilder,
      highlighted: highlighted,
      invalidBlocks: invalidBlocks,
      lines: lines,
      namedSections: namedSections,
      visibleHighlighted: hiddenRanges
          .cutHighlighted(highlighted)
          ?.splitLines(),
      visibleText: hiddenRanges.cutString(text),
      visibleSectionNames: visibleSectionNames,
    );
  }

  static TextSelection _clampSelection(
    TextSelection selection,
    int textLength,
  ) {
    int clampOffset(int offset) {
      if (offset < 0) {
        return 0;
      }
      if (offset > textLength) {
        return textLength;
      }
      return offset;
    }

    return selection.copyWith(
      baseOffset: clampOffset(selection.baseOffset),
      extentOffset: clampOffset(selection.extentOffset),
    );
  }
}
