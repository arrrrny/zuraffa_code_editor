// Maps between a global text offset and a (line index, column offset) pair.
//
// re_editor addresses text by line index plus a column offset within that
// line; the rest of this package - and Flutter's own `TextSelection` -
// addresses it by a single global offset. Folding makes the two disagree even
// more: the editor renders the *visible* text, so an offset in it is not an
// offset in the full document.

class LinePositionMapper {
  /// Creates a mapper over [text].
  ///
  /// The line start offsets are computed once, so resolving a position is
  /// O(log n) rather than a scan of the whole document.
  LinePositionMapper(String text)
    : _text = text,
      _lineStarts = _computeLineStarts(text);

  final String _text;
  final List<int> _lineStarts;

  /// Offset at which each line begins.
  List<int> get lineStarts => _lineStarts;

  /// Number of lines in the text.
  int get lineCount => _lineStarts.length;

  /// The (line, column) pair for the global [offset].
  ///
  /// An offset past the end of the text clamps to the end of the last line; a
  /// negative offset clamps to the start of the first.
  ({int line, int column}) resolve(int offset) {
    if (_lineStarts.isEmpty) {
      return (line: 0, column: 0);
    }

    final clamped = offset.clamp(0, _text.length);
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_lineStarts[mid] <= clamped) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return (line: low, column: clamped - _lineStarts[low]);
  }

  /// The global offset for the given (line, column) pair.
  ///
  /// A line index past the last line clamps to the end of the text; a column
  /// past the end of its line clamps to the end of that line.
  int toOffset(int line, int column) {
    if (_lineStarts.isEmpty) {
      return 0;
    }
    if (line < 0) {
      return 0;
    }
    if (line >= _lineStarts.length) {
      return _text.length;
    }
    final start = _lineStarts[line];
    final end = _lineEnd(line);
    return (start + column).clamp(start, end);
  }

  /// The global offset at which [line] ends (before its line break).
  int _lineEnd(int line) {
    final start = _lineStarts[line];
    final next = line + 1 < _lineStarts.length
        ? _lineStarts[line + 1]
        : _text.length;
    var end = next;
    // Only trim a trailing line break when this line actually contains
    // characters: an empty trailing line (start == end) has nothing to trim,
    // and trimming would make `end < start`, which breaks `clamp`.
    if (end > start && end <= _text.length && _text[end - 1] == '\n') {
      end--;
    }
    if (end > start && end <= _text.length && _text[end - 1] == '\r') {
      end--;
    }
    if (end < start) {
      end = start;
    }
    return end;
  }

  static List<int> _computeLineStarts(String text) {
    final starts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        starts.add(i + 1);
      }
    }
    return starts;
  }
}
