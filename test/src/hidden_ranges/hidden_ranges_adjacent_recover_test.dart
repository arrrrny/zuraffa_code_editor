import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_range.dart';
import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_ranges.dart';

/// Two hidden ranges that touch (`first.end == second.start`) collapse onto the
/// same visible position, so recovering that position has to walk the run:
/// `TextAffinity.upstream` puts the whole run before the cursor and recovers the
/// end of the last range of the run, `downstream` recovers the start of the
/// first one. The third range only keeps the interpolation search away from
/// its degenerate all-ranges-collapse-together case.
void main() {
  // 0123456789...
  //          [h][h]                         [hidden]
  //          10 12 15                        30   40
  final touching = HiddenRanges(
    ranges: const [
      HiddenRange(10, 12, firstLine: 0, lastLine: 0, wholeFirstLine: false),
      HiddenRange(12, 15, firstLine: 0, lastLine: 0, wholeFirstLine: false),
      HiddenRange(30, 40, firstLine: 0, lastLine: 0, wholeFirstLine: false),
    ],
    textLength: 45,
  );

  test('both touching ranges collapse onto visible position 10', () {
    expect(touching.cutPosition(10), 10);
    expect(touching.cutPosition(12), 10);
    expect(touching.cutPosition(14), 10);
  });

  test('recovering with downstream affinity yields the run start', () {
    expect(
      touching.recoverPosition(10, placeHiddenRanges: TextAffinity.downstream),
      10,
    );
  });

  test('recovering with upstream affinity walks the run to its end', () {
    expect(
      touching.recoverPosition(10, placeHiddenRanges: TextAffinity.upstream),
      15,
    );
  });
}
