import 'dart:ui';

import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_range.dart';
import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

import 'common.dart';

/// A run of contiguous ranges `[10..11) [11..12)` preceded by a stand-alone
/// `[5..8)`. The two in the run fold onto each other at visible position 7,
/// so `recoverPosition(7, ...)` has to walk the run in whichever direction
/// the affinity asks for.
const _adjacentRanges = [
  HiddenRange(5, 8, firstLine: 0, lastLine: 0, wholeFirstLine: true),
  HiddenRange(10, 11, firstLine: 0, lastLine: 0, wholeFirstLine: true),
  HiddenRange(11, 12, firstLine: 0, lastLine: 0, wholeFirstLine: true),
];

/// The visible position both `[10..11)` and `[11..12)` collapse to.
const _collapsePosition = 7;

void main() {
  group('HiddenRanges, contiguous collapses', () {
    test('downstream collapses to the first of the run', () {
      final ranges = HiddenRanges(ranges: _adjacentRanges, textLength: 140);

      expect(
        ranges.recoverPosition(
          _collapsePosition,
          placeHiddenRanges: TextAffinity.downstream,
        ),
        10,
      );
    });

    test('upstream collapses to the last of the run', () {
      final ranges = HiddenRanges(ranges: _adjacentRanges, textLength: 140);

      expect(
        ranges.recoverPosition(
          _collapsePosition,
          placeHiddenRanges: TextAffinity.upstream,
        ),
        12,
      );
    });

    test('a run with a longer tail still walks to its end', () {
      final ranges = HiddenRanges(
        ranges: const [
          HiddenRange(5, 8, firstLine: 0, lastLine: 0, wholeFirstLine: true),
          HiddenRange(10, 11, firstLine: 0, lastLine: 0, wholeFirstLine: true),
          HiddenRange(11, 12, firstLine: 0, lastLine: 0, wholeFirstLine: true),
          HiddenRange(12, 13, firstLine: 0, lastLine: 0, wholeFirstLine: true),
        ],
        textLength: 140,
      );

      expect(
        ranges.recoverPosition(
          _collapsePosition,
          placeHiddenRanges: TextAffinity.downstream,
        ),
        10,
      );
      expect(
        ranges.recoverPosition(
          _collapsePosition,
          placeHiddenRanges: TextAffinity.upstream,
        ),
        13,
      );
    });
  });

  group('HiddenRanges hashCode', () {
    test('follows the ranges and the text length', () {
      final left = HiddenRanges(ranges: _adjacentRanges, textLength: 140);
      final right = HiddenRanges(ranges: _adjacentRanges, textLength: 140);

      expect(left.hashCode, right.hashCode);
      expect(left, right);
    });

    test('differs when the ranges differ', () {
      final left = HiddenRanges(ranges: _adjacentRanges, textLength: 140);
      final right = HiddenRanges.empty;

      expect(left.hashCode, isNot(right.hashCode));
      expect(left, isNot(right));
    });

    test('differs when only the text length differs', () {
      final left = HiddenRanges(ranges: _adjacentRanges, textLength: 140);
      final right = HiddenRanges(ranges: _adjacentRanges, textLength: 141);

      expect(left.hashCode, isNot(right.hashCode));
      expect(left, isNot(right));
    });

    test('the shared fixture is stable', () {
      final copy = HiddenRanges(
        ranges: const [
          HiddenRange(20, 23, firstLine: 0, lastLine: 0, wholeFirstLine: true),
          HiddenRange(31, 42, firstLine: 0, lastLine: 0, wholeFirstLine: true),
          HiddenRange(67, 91, firstLine: 0, lastLine: 0, wholeFirstLine: true),
          HiddenRange(
            100,
            101,
            firstLine: 0,
            lastLine: 0,
            wholeFirstLine: true,
          ),
          HiddenRange(
            102,
            103,
            firstLine: 0,
            lastLine: 0,
            wholeFirstLine: true,
          ),
          HiddenRange(
            104,
            105,
            firstLine: 0,
            lastLine: 0,
            wholeFirstLine: true,
          ),
          HiddenRange(
            106,
            107,
            firstLine: 0,
            lastLine: 0,
            wholeFirstLine: true,
          ),
          HiddenRange(
            108,
            109,
            firstLine: 0,
            lastLine: 0,
            wholeFirstLine: true,
          ),
          HiddenRange(
            110,
            111,
            firstLine: 0,
            lastLine: 0,
            wholeFirstLine: true,
          ),
          HiddenRange(
            113,
            123,
            firstLine: 0,
            lastLine: 0,
            wholeFirstLine: true,
          ),
        ],
        textLength: 140,
      );

      expect(hiddenRanges.hashCode, copy.hashCode);
      expect(hiddenRanges, copy);
    });
  });
}
