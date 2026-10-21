import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code_field/line_position_mapper.dart';

void main() {
  group('LinePositionMapper', () {
    test('resolves offsets to line and column', () {
      final mapper = LinePositionMapper('abc\ndef\nghi');
      expect(mapper.resolve(0), (line: 0, column: 0));
      expect(mapper.resolve(2), (line: 0, column: 2));
      expect(mapper.resolve(4), (line: 1, column: 0));
      expect(mapper.resolve(6), (line: 1, column: 2));
      expect(mapper.resolve(8), (line: 2, column: 0));
    });

    test('clamps out-of-range offsets', () {
      final mapper = LinePositionMapper('abc\ndef');
      expect(mapper.resolve(-5), (line: 0, column: 0));
      expect(mapper.resolve(999), (line: 1, column: 3));
    });

    test('maps line and column back to offsets', () {
      final mapper = LinePositionMapper('abc\ndef\nghi');
      expect(mapper.toOffset(0, 0), 0);
      expect(mapper.toOffset(0, 3), 3);
      expect(mapper.toOffset(1, 0), 4);
      expect(mapper.toOffset(2, 1), 9);
    });

    test('round-trips every offset', () {
      const text = 'abc\ndef\n\nghi';
      final mapper = LinePositionMapper(text);
      for (var offset = 0; offset <= text.length; offset++) {
        final pos = mapper.resolve(offset);
        expect(mapper.toOffset(pos.line, pos.column), offset);
      }
    });

    test('handles empty text', () {
      final mapper = LinePositionMapper('');
      expect(mapper.lineCount, 1);
      expect(mapper.resolve(0), (line: 0, column: 0));
      expect(mapper.toOffset(0, 0), 0);
    });

    test('handles text ending with a newline', () {
      final mapper = LinePositionMapper('abc\n');
      expect(mapper.lineCount, 2);
      expect(mapper.resolve(4), (line: 1, column: 0));
    });

    test('exposes the offsets the lines begin at', () {
      final mapper = LinePositionMapper('abc\ndef');
      expect(mapper.lineStarts, [0, 4]);
    });

    test('maps a line past the end of the text to the end of the text', () {
      final mapper = LinePositionMapper('abc\ndef');
      expect(mapper.toOffset(99, 0), 7);
    });

    test('a carriage return ends the line before the line feed', () {
      final mapper = LinePositionMapper('abc\r\ndef');
      expect(mapper.toOffset(0, 99), 3);
      expect(mapper.toOffset(1, 0), 5);
    });
  });
}
