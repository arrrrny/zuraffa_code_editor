import 'package:zuraffa_code_editor/src/hidden_ranges/line_numbering_breakpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineNumberingBreakpoint', () {
    group('cutLineIndex', () {
      const breakpoint = LineNumberingBreakpoint(
        full: 100,
        visible: 12,
        spreadBefore: 4,
      );

      test('way before', () {
        expect(breakpoint.cutLineIndex(-10), -14);
      });

      test('last line before', () {
        expect(breakpoint.cutLineIndex(15), 11);
      });

      test('first hidden line', () {
        expect(breakpoint.cutLineIndex(16), 11);
      });

      test('mid hidden line', () {
        expect(breakpoint.cutLineIndex(50), 11);
      });

      test('last hidden line', () {
        expect(breakpoint.cutLineIndex(99), 11);
      });

      test('first line after', () {
        expect(breakpoint.cutLineIndex(100), 12);
      });

      test('way after', () {
        expect(breakpoint.cutLineIndex(200), 112);
      });
    });

    group('cutLineIndexIfVisible', () {
      const breakpoint = LineNumberingBreakpoint(
        full: 100,
        visible: 12,
        spreadBefore: 4,
      );

      test('way before', () {
        expect(breakpoint.cutLineIndexIfVisible(-10), -14);
      });

      test('last line before', () {
        expect(breakpoint.cutLineIndexIfVisible(15), 11);
      });

      test('first hidden line', () {
        expect(breakpoint.cutLineIndexIfVisible(16), null);
      });

      test('mid hidden line', () {
        expect(breakpoint.cutLineIndexIfVisible(50), null);
      });

      test('last hidden line', () {
        expect(breakpoint.cutLineIndexIfVisible(99), null);
      });

      test('first line after', () {
        expect(breakpoint.cutLineIndexIfVisible(100), 12);
      });

      test('way after', () {
        expect(breakpoint.cutLineIndexIfVisible(200), 112);
      });
    });

    group('derived spread values', () {
      const breakpoint = LineNumberingBreakpoint(
        full: 100,
        visible: 12,
        spreadBefore: 4,
      );

      test('spread is full minus visible', () {
        expect(breakpoint.spread, 88);
      });

      test('addedSpread excludes what was already spread before', () {
        expect(breakpoint.addedSpread, 84);
      });

      test('fullBefore is the last full line on the old numbering', () {
        expect(breakpoint.fullBefore, 16);
      });

      test('a zero spreadBefore keeps the breakpoint on the first line', () {
        const breakpoint = LineNumberingBreakpoint(
          full: 10,
          visible: 8,
          spreadBefore: 0,
        );

        expect(breakpoint.spread, 2);
        expect(breakpoint.addedSpread, 2);
        expect(breakpoint.fullBefore, 8);
      });
    });

    group('toString and props', () {
      const breakpoint = LineNumberingBreakpoint(
        full: 100,
        visible: 12,
        spreadBefore: 4,
      );

      test('toString names the mapping', () {
        expect(
          breakpoint.toString(),
          'LineNumberingBreakpoint: 100 -> 12 (spreadBefore = 4)',
        );
      });

      test('props are the three coordinates', () {
        expect(breakpoint.props, [100, 12, 4]);
      });

      test('equality follows props', () {
        expect(
          breakpoint,
          const LineNumberingBreakpoint(
            full: 100,
            visible: 12,
            spreadBefore: 4,
          ),
        );
      });
    });
  });
}
