import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

import 'gutter_alignment_harness.dart';

/// Which properties of `GutterStyle.textStyle` a host may still set, and which
/// the editor takes from `CodeField.textStyle` — upstream #260's property audit,
/// pinned as tests rather than left as a claim in a doc comment.
///
/// `CodeField._buildGutter` (`code_field.dart:787-798`) builds the gutter's
/// style from the host's `GutterStyle.textStyle` and then `copyWith`s four
/// properties from the code area's style: `color` resolved through the host's
/// own colour, and `fontFamily`, `fontSize` and `height` taken from the code's.
/// Those three metrics are the only properties that decide how tall a line box
/// is, so they are the only ones that can put the gutter's grid off the code's
/// grid — and per #260 they are the ones the host must not be able to change by
/// accident.
///
/// The colour, the weight, the style and the tracking change how the numbers
/// look without changing where their rows sit, so those a host keeps.

/// The code area's style in every test here.
///
/// `height` is set because `expectEditorLineHeightSet` requires one for the
/// invariant to mean anything: without it both grids fall back to the font's
/// own metrics and nothing distinguishes "aligned" from "both wrong the same
/// way".
const TextStyle _codeStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  fontFamily: 'JetBrainsMono',
  color: Color(0xFF00AA00),
);

/// The style the gutter actually renders with.
TextStyle _gutterStyle(WidgetTester wt) =>
    wt.widget<GutterWidget>(find.byType(GutterWidget)).style.textStyle ??
    const TextStyle();

void main() {
  testWidgets(
    'a differing gutter fontSize cannot move the gutter off the grid',
    (wt) async {
      final controller = await pumpGutterAlignmentEditor(
        wt,
        textStyle: _codeStyle,
        gutterStyle: const GutterStyle(
          textStyle: TextStyle(
            fontSize: 40,
            fontFamily: 'Courier',
            height: 3.5,
            color: Color(0xFF123456),
          ),
        ),
      );

      expectEditorLineHeightSet(wt, controller);

      final style = _gutterStyle(wt);
      expect(
        style.fontSize,
        13,
        reason:
            'fontSize is one of three metrics that set the line box, and it '
            'must come from the code area',
      );
      expect(style.fontFamily, 'JetBrainsMono');
      expect(style.height, 1.6);
      expect(
        style.color,
        const Color(0xFF123456),
        reason: 'the host asked for this colour and the colour is not a metric',
      );

      expectOnGrid(
        gutterRows(wt, controller),
        top: textTop(wt, controller),
        lineHeight: renderedLineHeight(wt, controller),
        state: 'Gutter fontSize 40',
      );
    },
  );

  testWidgets(
    'a differing gutter fontFamily cannot move the gutter off the grid',
    (wt) async {
      final controller = await pumpGutterAlignmentEditor(
        wt,
        textStyle: _codeStyle,
        gutterStyle: const GutterStyle(
          textStyle: TextStyle(
            fontSize: 9,
            fontFamily: 'Courier New',
            height: 2.4,
          ),
        ),
      );

      expectEditorLineHeightSet(wt, controller);

      final style = _gutterStyle(wt);
      expect(style.fontFamily, 'JetBrainsMono');
      expect(style.fontSize, 13);
      expect(style.height, 1.6);

      expectOnGrid(
        gutterRows(wt, controller),
        top: textTop(wt, controller),
        lineHeight: renderedLineHeight(wt, controller),
        state: 'Gutter fontFamily Courier New',
      );
    },
  );

  testWidgets('a differing gutter height cannot move the gutter off the grid', (
    wt,
  ) async {
    final controller = await pumpGutterAlignmentEditor(
      wt,
      textStyle: _codeStyle,
      gutterStyle: const GutterStyle(
        textStyle: TextStyle(fontSize: 20, height: 3),
      ),
    );

    expectEditorLineHeightSet(wt, controller);

    final style = _gutterStyle(wt);
    expect(
      style.height,
      1.6,
      reason:
          'height is the line-height multiplier, and the gutter row must be '
          'exactly one code line tall',
    );
    expect(style.fontSize, 13);

    expectOnGrid(
      gutterRows(wt, controller),
      top: textTop(wt, controller),
      lineHeight: renderedLineHeight(wt, controller),
      state: 'Gutter height 3',
    );
  });

  testWidgets('all three metrics at once cannot move the gutter off the grid', (
    wt,
  ) async {
    final controller = await pumpGutterAlignmentEditor(
      wt,
      textStyle: _codeStyle,
      gutterStyle: const GutterStyle(
        textStyle: TextStyle(fontSize: 44, fontFamily: 'Roboto', height: 4),
      ),
    );

    expectOnGrid(
      gutterRows(wt, controller),
      top: textTop(wt, controller),
      lineHeight: renderedLineHeight(wt, controller),
      state: 'All three metrics hostile',
    );
  });

  testWidgets('the same holds under Material 3', (wt) async {
    final controller = await pumpGutterAlignmentEditor(
      wt,
      useMaterial3: true,
      textStyle: _codeStyle,
      gutterStyle: const GutterStyle(
        textStyle: TextStyle(fontSize: 30, height: 3),
      ),
    );

    expectEditorLineHeightSet(wt, controller);
    expect(_gutterStyle(wt).fontSize, 13);

    expectOnGrid(
      gutterRows(wt, controller),
      top: textTop(wt, controller),
      lineHeight: renderedLineHeight(wt, controller),
      state: 'Material 3, hostile gutter style',
    );
  });

  testWidgets('colour, weight, style and tracking stay overridable', (
    wt,
  ) async {
    const hostile = Color(0xFF0000CC);

    final controller = await pumpGutterAlignmentEditor(
      wt,
      textStyle: _codeStyle,
      gutterStyle: const GutterStyle(
        textStyle: TextStyle(
          color: hostile,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: 2,
        ),
      ),
    );

    final style = _gutterStyle(wt);
    expect(
      style.color,
      hostile,
      reason: 'colour is cosmetic — the host asked for it, it gets it',
    );
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.letterSpacing, 2);
    expect(
      style.fontSize,
      13,
      reason: 'and the metrics still come from the code area',
    );

    expectOnGrid(
      gutterRows(wt, controller),
      top: textTop(wt, controller),
      lineHeight: renderedLineHeight(wt, controller),
      state: 'Overridden colour, weight, style, tracking',
    );
  });

  testWidgets('an omitted gutter style takes the code colour at half alpha', (
    wt,
  ) async {
    final controller = await pumpGutterAlignmentEditor(
      wt,
      textStyle: _codeStyle,
    );

    expect(
      _gutterStyle(wt).color,
      const Color(0xFF00AA00).withValues(alpha: .5),
      reason:
          'the documented fallback, and the one a host gets by caring about '
          'nothing — the code area colour dimmed to half',
    );

    expectOnGrid(
      gutterRows(wt, controller),
      top: textTop(wt, controller),
      lineHeight: renderedLineHeight(wt, controller),
      state: 'No gutter textStyle',
    );
  });
}
