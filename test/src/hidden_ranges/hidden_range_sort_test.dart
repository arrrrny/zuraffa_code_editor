import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HiddenRange.sort', () {
    HiddenRange range(int start, int end) => HiddenRange(
      start,
      end,
      firstLine: 0,
      lastLine: 0,
      wholeFirstLine: true,
    );

    test('orders by start', () {
      final ranges = [range(10, 20), range(2, 30), range(5, 6)];

      ranges.sort(HiddenRange.sort);

      expect(ranges.map((r) => '${r.start}-${r.end}'), [
        '2-30',
        '5-6',
        '10-20',
      ]);
    });

    test('breaks a tie on start by end, ascending', () {
      final ranges = [range(4, 9), range(4, 6), range(4, 7)];

      ranges.sort(HiddenRange.sort);

      expect(ranges.map((r) => '${r.start}-${r.end}'), ['4-6', '4-7', '4-9']);
    });
  });
}
