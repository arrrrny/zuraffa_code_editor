import 'package:highlight/highlight_core.dart';

import '../../code/code_lines.dart';
import '../foldable_block_type.dart';
import 'abstract.dart';

/// A parser for foldable blocks in markup, read from the raw text.
///
/// The markup parser that reads the highlight's node tree is more precise: it
/// knows from the highlighting which `<` is a tag and which is a piece of text.
/// This one has no such help and finds the tags itself, skipping the places
/// where a `<` does not open a tag — a comment, a CDATA section, a processing
/// instruction, a doctype.
///
/// The structure it finds is the same: an element opens a block, its closing
/// tag closes it, and a self-closing element opens none.
class MarkupFallbackFoldableBlockParser extends AbstractFoldableBlockParser {
  /// The text the tags are looked for in.
  String _text = '';

  /// The line the scan is on.
  int _lineIndex = 0;

  @override
  void parse({
    required Result highlighted,
    required Set<Object?> serviceCommentsSources,
    required CodeLines lines,
  }) {
    final nodes = highlighted.nodes;
    if (nodes == null || nodes.length != 1 || nodes.first.value == null) {
      throw Exception('A single-node highlighted result is required for this.');
    }

    _text = nodes.first.value!;
    _scan();
    finalize();
  }

  void _scan() {
    var i = 0;
    final length = _text.length;

    while (i < length) {
      final c = _text.codeUnitAt(i);
      if (c != _lessThan) {
        if (c == _lineFeed) {
          _lineIndex++;
        }
        i++;
        continue;
      }

      final skipped = _skipNonTag(i);
      if (skipped != null) {
        _countLines(i, skipped);
        i = skipped;
        continue;
      }

      final tag = _readTag(i);
      if (tag == null) {
        i++;
        continue;
      }

      if (tag.isClosing) {
        endBlock(tag.startLine, FoldableBlockType.markup);
      } else if (!tag.isSelfClosing) {
        startBlock(tag.startLine, FoldableBlockType.markup);
      }

      i = tag.end;
    }
  }

  /// The end of the construct at [start], when it is one that holds no tags.
  ///
  /// A comment, a CDATA section, a processing instruction and a doctype all
  /// may hold `<` characters that open no tag, so the scan skips over them
  /// whole.
  int? _skipNonTag(int start) {
    if (_text.startsWith('<!--', start)) {
      return _indexAfter('-->', start + 4);
    }
    if (_text.startsWith('<![CDATA[', start)) {
      return _indexAfter(']]>', start + 9);
    }
    if (_text.startsWith('<?', start)) {
      return _indexAfter('?>', start + 2);
    }
    if (_text.startsWith('<!', start)) {
      return _indexAfter('>', start + 2);
    }
    return null;
  }

  /// Counts the line feeds between [from] and [to].
  void _countLines(int from, int to) {
    for (var i = from; i < to; i++) {
      if (_text.codeUnitAt(i) == _lineFeed) {
        _lineIndex++;
      }
    }
  }

  /// The end of the construct at [start] plus the length of [sequence].
  int _indexAfter(String sequence, int from) {
    final index = _text.indexOf(sequence, from);
    if (index == -1) {
      return _text.length;
    }
    return index + sequence.length;
  }

  /// The tag at [start], or null when there is none.
  _MarkupTag? _readTag(int start) {
    var i = start + 1;
    final length = _text.length;
    final startLine = _lineIndex;

    final isClosing = i < length && _text.codeUnitAt(i) == _slash;
    if (isClosing) {
      i++;
    }

    final nameStart = i;
    while (i < length && _isNameChar(_text.codeUnitAt(i))) {
      i++;
    }

    if (i == nameStart) {
      // A `<` that opens no name is a piece of text, not a tag.
      return null;
    }

    // The rest of the tag: the attributes, which may hold a `>` inside a
    // quoted value.
    var selfClosing = false;
    while (i < length) {
      final c = _text.codeUnitAt(i);
      if (c == _doubleQuote || c == _singleQuote) {
        i = _indexAfter(_text[i], i + 1);
        continue;
      }
      if (c == _greaterThan) {
        break;
      }
      if (c == _slash &&
          i + 1 < length &&
          _text.codeUnitAt(i + 1) == _greaterThan) {
        selfClosing = true;
        break;
      }
      if (c == _lineFeed) {
        _lineIndex++;
      }
      i++;
    }

    if (i >= length) {
      return null;
    }

    return _MarkupTag(
      end: i + 1,
      startLine: startLine,
      isClosing: isClosing,
      isSelfClosing: selfClosing,
    );
  }

  bool _isNameChar(int c) {
    return (c >= _a && c <= _z) ||
        (c >= _upperA && c <= _upperZ) ||
        (c >= _zero && c <= _nine) ||
        c == _underscore ||
        c == _dash ||
        c == _colon;
  }

  static const int _lessThan = 0x3C;
  static const int _greaterThan = 0x3E;
  static const int _slash = 0x2F;
  static const int _doubleQuote = 0x22;
  static const int _singleQuote = 0x27;
  static const int _lineFeed = 0x0A;
  static const int _underscore = 0x5F;
  static const int _dash = 0x2D;
  static const int _colon = 0x3A;
  static const int _a = 0x61;
  static const int _z = 0x7A;
  static const int _upperA = 0x41;
  static const int _upperZ = 0x5A;
  static const int _zero = 0x30;
  static const int _nine = 0x39;
}

class _MarkupTag {
  final int end;

  /// The line the tag starts on, which is not the line it ends on when the
  /// tag spans several lines.
  final int startLine;
  final bool isClosing;
  final bool isSelfClosing;

  const _MarkupTag({
    required this.end,
    required this.startLine,
    required this.isClosing,
    required this.isSelfClosing,
  });
}
