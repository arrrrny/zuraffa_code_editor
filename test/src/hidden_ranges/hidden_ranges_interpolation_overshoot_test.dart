import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_range.dart';
import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_ranges.dart';

/// The interpolation search in `cutPosition` narrows with `upperRange =
/// rangeIndex - 1` whenever the probed range starts *after* the position. The
/// next probe then measures the position against a much closer `upperChar`, and
/// the estimate can overshoot past the narrowed upper bound — the position is
/// far to the right of the remaining ranges' ends. That overshoot is what the
/// `rangeIndex > upperRange` guard catches, and it has to return the visible
/// position measured against the one range that still follows it.
void main() {
  final overshooting = HiddenRanges(
    ranges: const [
      //            0    10   20   40   50 hidden characters before each range
      HiddenRange(
        0,
        10,
        firstLine: 0,
        lastLine: 0,
        wholeFirstLine: false,
      ), //   0
      HiddenRange(
        50,
        60,
        firstLine: 0,
        lastLine: 0,
        wholeFirstLine: false,
      ), // 10
      HiddenRange(
        80,
        100,
        firstLine: 0,
        lastLine: 0,
        wholeFirstLine: false,
      ), //20
      HiddenRange(
        170,
        180,
        firstLine: 0,
        lastLine: 0,
        wholeFirstLine: false,
      ), //40
      HiddenRange(
        190,
        200,
        firstLine: 0,
        lastLine: 0,
        wholeFirstLine: false,
      ), //50
    ],
    textLength: 260,
  );

  test('a position past the narrowed upper bound uses the earlier offset', () {
    // 160 sits after range 2 (which hides 20 characters so far) and before
    // range 3, so the probe overshoots range 2 and the guard answers with the
    // visible length of everything up to — and including — range 2.
    expect(overshooting.cutPosition(160), 160 - 40);

    // Neighbours of the same gap agree, which pins the arithmetic the guard
    // returns rather than just the fact that it returned.
    expect(overshooting.cutPosition(161), 161 - 40);
    expect(overshooting.cutPosition(169), 169 - 40);
  });
}
