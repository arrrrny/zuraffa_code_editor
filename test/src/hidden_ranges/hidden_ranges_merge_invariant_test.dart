import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_range.dart';
import 'package:zuraffa_code_editor/src/hidden_ranges/hidden_ranges.dart';
import 'package:zuraffa_code_editor/src/search/match.dart';
import 'package:zuraffa_code_editor/src/search/result.dart';

import 'common.dart';

/// Three ranges with gaps between all of them: nothing merged, nothing
/// touching. `hiddenCharactersBeforeRanges` over it is `[0, 3, 6, 17]`.
const _gappedRanges = [
  HiddenRange(5, 8, firstLine: 0, lastLine: 0, wholeFirstLine: false),
  HiddenRange(20, 23, firstLine: 0, lastLine: 0, wholeFirstLine: false),
  HiddenRange(31, 42, firstLine: 0, lastLine: 0, wholeFirstLine: false),
];

/// Where each range of [_gappedRanges] collapses in the visible text:
/// its start minus the characters hidden before it.
const _collapsePositions = [5, 17, 25];

/// Two ranges that touch: the shape `HiddenRangesBuilder` never emits because
/// it merges, and the shape the constructor must now refuse.
const _touchingRanges = [
  HiddenRange(10, 12, firstLine: 0, lastLine: 0, wholeFirstLine: false),
  HiddenRange(12, 15, firstLine: 0, lastLine: 0, wholeFirstLine: false),
];

/// Two ranges that overlap: the shape that was always invalid and still is.
const _overlappingRanges = [
  HiddenRange(10, 12, firstLine: 0, lastLine: 0, wholeFirstLine: false),
  HiddenRange(11, 15, firstLine: 0, lastLine: 0, wholeFirstLine: false),
];

/// Out of order: sortedness was part of the old invariant and stays part of the
/// new one.
const _unsortedRanges = [
  HiddenRange(31, 42, firstLine: 0, lastLine: 0, wholeFirstLine: false),
  HiddenRange(5, 8, firstLine: 0, lastLine: 0, wholeFirstLine: false),
];

void main() {
  group('the merged invariant', () {
    test('touching ranges fail the assert', () {
      expect(
        () => HiddenRanges(ranges: _touchingRanges, textLength: 45),
        throwsA(
          isA<AssertionError>()
              .having((e) => e.message, 'message', contains('merges'))
              .having((e) => e.message, 'message', contains('non-adjacent')),
        ),
        reason:
            'Two ranges that touch are one merged range the caller forgot to '
            'merge. `HiddenRangesBuilder` never emits that shape, so the only '
            'way to get one in is to construct it by hand.',
      );
    });

    test('out-of-order ranges fail the assert', () {
      expect(
        () => HiddenRanges(ranges: _unsortedRanges, textLength: 45),
        throwsA(isA<AssertionError>()),
      );
    });

    test('gapped, single and empty ranges construct', () {
      expect(
        HiddenRanges(ranges: _gappedRanges, textLength: 140).ranges.length,
        3,
      );

      final single = HiddenRanges(
        ranges: const [
          HiddenRange(10, 12, firstLine: 0, lastLine: 0, wholeFirstLine: false),
        ],
        textLength: 45,
      );
      expect(single.ranges.length, 1);

      expect(HiddenRanges.empty.ranges, isEmpty);
    });

    test('overlapping ranges still fail', () {
      expect(
        () => HiddenRanges(ranges: _overlappingRanges, textLength: 45),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('recovering a collapse position', () {
    // The loops that walked runs of touching ranges are gone; each collapse is
    // a single range now, so recovering it is that range's own start or end.
    final ranges = HiddenRanges(ranges: _gappedRanges, textLength: 140);

    test('downstream returns the start of the collapsing range', () {
      for (var i = 0; i < _collapsePositions.length; i++) {
        expect(
          ranges.recoverPosition(
            _collapsePositions[i],
            placeHiddenRanges: TextAffinity.downstream,
          ),
          _gappedRanges[i].start,
          reason:
              'Collapse $_collapsePositions[i] is range '
              '${_gappedRanges[i].start}-${_gappedRanges[i].end}',
        );
      }
    });

    test('upstream returns the end of the collapsing range', () {
      for (var i = 0; i < _collapsePositions.length; i++) {
        expect(
          ranges.recoverPosition(
            _collapsePositions[i],
            placeHiddenRanges: TextAffinity.upstream,
          ),
          _gappedRanges[i].end,
          reason:
              'Collapse $_collapsePositions[i] is range '
              '${_gappedRanges[i].start}-${_gappedRanges[i].end}',
        );
      }
    });
  });

  group('cutting on a merged list', () {
    final ranges = HiddenRanges(ranges: _gappedRanges, textLength: 140);

    test('cutPosition maps a hidden position to the range start', () {
      // [5, 8) hides 5-7, [20, 23) hides 20-22.
      expect(ranges.cutPosition(3), 3, reason: 'before the first range');
      expect(ranges.cutPosition(6), 5, reason: 'inside the first range');
      expect(ranges.cutPosition(21), 17, reason: 'inside a middle range');
      expect(
        ranges.cutPosition(45),
        28,
        reason: 'after the last range: 45 - 17 hidden characters',
      );
    });

    test('cutSelection and recoverSelection are the pair they claim', () {
      final cut = ranges.cutSelection(
        const TextSelection(baseOffset: 21, extentOffset: 25),
      );
      expect(cut.baseOffset, 17);
      expect(cut.extentOffset, 19);

      expect(
        ranges.recoverSelection(const TextSelection.collapsed(offset: 17)),
        const TextSelection.collapsed(offset: 20),
      );
    });

    test('cutSearchResult moves match bounds with the text', () {
      final cut = ranges.cutSearchResult(
        const SearchResult(matches: [SearchMatch(start: 4, end: 21)]),
      );

      expect(cut.matches.single.start, 4);
      expect(cut.matches.single.end, 17);
    });

    test('cutString removes hidden characters mid-window', () {
      // Characters 5-7 are hidden, so the window starting at 5 loses three.
      expect(ranges.cutString('56789', start: 5), '89');
      expect(ranges.cutString('0123', start: 0), '0123');
    });
  });

  group('hashCode', () {
    test('equal ranges and equal text lengths hash equal', () {
      expect(
        HiddenRanges(ranges: _gappedRanges, textLength: 140).hashCode,
        HiddenRanges(ranges: _gappedRanges, textLength: 140).hashCode,
      );
    });

    test('differs when only the text length differs', () {
      expect(
        HiddenRanges(ranges: _gappedRanges, textLength: 140).hashCode,
        isNot(HiddenRanges(ranges: _gappedRanges, textLength: 141).hashCode),
      );
    });

    test('differs when the ranges differ', () {
      final left = HiddenRanges(ranges: _gappedRanges, textLength: 140);

      expect(left.hashCode, isNot(HiddenRanges.empty.hashCode));
      expect(left, isNot(HiddenRanges.empty));
    });

    test('the shared fixture is stable across list instances', () {
      expect(
        hiddenRanges.hashCode,
        HiddenRanges(
          ranges: List.of(hiddenRanges.ranges),
          textLength: hiddenRanges.textLength,
        ).hashCode,
      );
      expect(
        hiddenRanges,
        HiddenRanges(
          ranges: List.of(hiddenRanges.ranges),
          textLength: hiddenRanges.textLength,
        ),
      );
    });
  });
}
