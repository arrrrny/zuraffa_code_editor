import 'package:flutter/widgets.dart';
import 'package:highlight/highlight_core.dart';

import '../code/code.dart';
import '../code/text_style.dart';
import '../code_theme/code_theme_data.dart';
import '../highlight/node.dart';

/// Appended to the end of a folded block's kept line, so a line whose content
/// is hidden does not read as merely short.
///
/// The gutter already hangs a chevron on the kept line's row
/// (`gutter/fold_toggle.dart`), but that is a row affordance, not a text one: a
/// host that hides the gutter, and a reader looking at the text rather than at
/// the gutter, is left with `parsers: [` and nothing to say that it continues
/// out of sight (akvelon/flutter-code-editor#86).
///
/// The leading space keeps the marker clear of a closer the fold glued to the
/// kept line: `parsers: [  ], …`.
///
/// The marker belongs to the rendering only, never to `Code.visibleText`:
/// that is the editing buffer, and every offset the field maps through it —
/// caret, selection, `cutSelection`/`recoverSelection`, the derived
/// `LineNumberingBreakpoint`s, gutter numbering — would shift by it.
const _foldEllipsis = ' …';

class SpanBuilder {
  final Code code;
  final CodeThemeData? theme;
  final TextStyle? rootStyle;

  /// Whether folded blocks' kept lines are marked.
  ///
  /// The search path turns this off: `SearchResultHighlightedBuilder` slices
  /// the tree by match offsets measured against `Code.visibleText`, so a
  /// character the tree carries that `visibleText` does not have shifts every
  /// match that follows it.
  final bool withFoldEllipsis;

  int _visibleLineIndex = 0;

  /// Visible line indexes of folded blocks' kept lines, resolved once per
  /// [build] — a fold set does not change while a tree is being walked.
  Set<int> _foldedKeptLines = const {};

  SpanBuilder({
    required this.code,
    required this.theme,
    this.rootStyle,
    this.withFoldEllipsis = true,
  });

  TextSpan build() {
    _visibleLineIndex = 0;
    _foldedKeptLines = _foldedKeptLineIndexes();

    final children = _buildList(
      nodes: code.visibleHighlighted?.nodes ?? [],
      theme: theme,
      ancestorStyle: rootStyle,
    );

    // `_visibleLineIndex` counts the newlines walked so far, so with the tree
    // ending mid-line it is the last visible line itself — the one line with no
    // terminating newline to splice a marker in front of. A tree ending with a
    // newline has an empty visible line after it, which is never a fold's kept
    // line, so the check below needs no companion test for it.
    if (!withFoldEllipsis || !_foldedKeptLines.contains(_visibleLineIndex)) {
      return TextSpan(style: rootStyle, children: children);
    }

    return TextSpan(
      style: rootStyle,
      children: [
        ...?children,
        TextSpan(text: _foldEllipsis, style: rootStyle),
      ],
    );
  }

  List<TextSpan>? _buildList({
    required List<Node>? nodes,
    required CodeThemeData? theme,
    TextStyle? ancestorStyle,
  }) {
    if (nodes == null) {
      return null;
    }

    return nodes
        .map(
          (node) => _buildNode(
            node: node,
            theme: theme,
            ancestorStyle: ancestorStyle,
          ),
        )
        .toList(growable: false);
  }

  TextSpan _buildNode({
    required Node node,
    required CodeThemeData? theme,
    TextStyle? ancestorStyle,
  }) {
    final style = theme?.styles[node.className] ?? ancestorStyle;
    final processedStyle = _paleIfRequired(style);

    _updateLineIndex(node);

    return _markFoldIfKeptLine(
      node: node,
      span: TextSpan(
        text: node.value,
        children: _buildList(
          nodes: node.children,
          theme: theme,
          ancestorStyle: style,
        ),
        style: processedStyle,
      ),
    );
  }

  void _updateLineIndex(Node node) {
    _visibleLineIndex += node.getValueNewlineCount();

    if (_visibleLineIndex >= code.lines.length) {
      _visibleLineIndex = code.lines.length - 1;
    }
  }

  /// Appends [_foldEllipsis] in front of the newline [node] ends its line
  /// with, when that line is a folded block's kept line.
  TextSpan _markFoldIfKeptLine({required Node node, required TextSpan span}) {
    final text = node.value;
    if (!withFoldEllipsis || text == null || !text.endsWith('\n')) {
      return span;
    }

    // A node ending with a newline terminates the line before the one the
    // counter has just moved on to.
    if (!_foldedKeptLines.contains(_visibleLineIndex - 1)) {
      return span;
    }

    // The run of newlines the value ends with starts exactly where the kept
    // line's content ends, whatever else the node spans: an empty kept line
    // (`foo(` / `` / `)`) puts the marker on the empty line, not after it.
    var runStart = text.length;
    while (runStart > 0 && text[runStart - 1] == '\n') {
      runStart--;
    }

    return TextSpan(
      style: span.style,
      children: [
        TextSpan(text: text.substring(0, runStart), style: span.style),
        // Children render after the node's own text, which is a newline: they
        // are already on the following line, so they stay behind the marker.
        ...?span.children,
        TextSpan(text: _foldEllipsis, style: rootStyle ?? span.style),
        TextSpan(text: text.substring(runStart), style: span.style),
      ],
    );
  }

  /// The visible line index of every folded block's kept line.
  ///
  /// A fold leaves the block's own first line on screen —
  /// `Code.foldableBlockToHiddenRange` starts the hidden range at the newline
  /// *before* the second line — so that line is where the marker belongs.
  /// A block nested inside an already folded one has that line hidden by the
  /// time the tree is built, and `cutLineIndexIfVisible` answers null for it:
  /// such a block has no visible kept line and gets no marker.
  Set<int> _foldedKeptLineIndexes() {
    final result = <int>{};

    for (final block in code.foldedBlocks) {
      final visible = code.hiddenLineRanges.cutLineIndexIfVisible(
        block.firstLine,
      );
      if (visible != null) {
        result.add(visible);
      }
    }

    return result;
  }

  TextStyle? _paleIfRequired(TextStyle? style) {
    if (code.visibleSectionNames.isNotEmpty) {
      return style;
    }

    final fullLineIndex = code.hiddenLineRanges.recoverLineIndex(
      _visibleLineIndex,
    );
    if (code.lines[fullLineIndex].isReadOnly) {
      return style?.paled();
    }
    return style;
  }
}
