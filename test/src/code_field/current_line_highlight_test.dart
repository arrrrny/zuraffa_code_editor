import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart';
import 'package:zuraffa_code_editor/src/code_field/line_background.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

const _tint = Color(0xFFFFE082);

/// A host builder's own colour, to prove which hook wins.
const _hostTint = Color(0xFF80CBC4);

/// A document whose first two lines are one and two characters: the shortest
/// lines that can still be tinted, so a tint's width can never be confused with
/// its own line's text width. The trailing newline leaves a fourth, empty line —
/// so this fixture also pins the trailing-newline case, and gives the caret four
/// distinct lines to be on.
const _document =
    'a\n'
    'bb\n'
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\n';

/// A document with a foldable block, so a fold can be opened over lines 0–2.
const _foldable =
    'class A {\n'
    '  int a;\n'
    '}\n'
    'd';

Future<CodeController> _pumpField(
  WidgetTester tester, {
  required String text,
  Color? Function(int)? lineBackgroundBuilder,
  Color? currentLineColor,
  TextSelection? selection,
  Set<String> visibleSectionNames = const {},
  Mode? language,
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = createController(
    text,
    language: language,
    visibleSectionNames: visibleSectionNames,
  );
  controller.lineBackgroundBuilder = lineBackgroundBuilder;
  controller.currentLineColor = currentLineColor;

  await tester.pumpWidget(createApp(controller, FocusNode()));
  await tester.pumpAndSettle();

  if (selection != null) {
    controller.selection = selection;
    controller.notifyListeners();
    await tester.pumpAndSettle();
  }

  return controller;
}

/// Every tinted row currently on screen, top to bottom.
List<Rect> _tintedRects(WidgetTester tester, Color color) {
  return tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(LineBackgroundLayer),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.color == color,
          ),
        ),
      )
      .map((w) => tester.getRect(find.byWidget(w)))
      .toList();
}

/// Every row the layer laid out — tinted or not — top to bottom.
///
/// Rows are a `Column`'s children, so the finder's depth-first order is the
/// visual order, which is what makes "which row is tinted" answerable by index.
List<Rect> _rowRects(WidgetTester tester) {
  return tester
      .widgetList<Widget>(
        find.descendant(
          of: find.byType(LineBackgroundLayer),
          matching: find.byWidgetPredicate(
            (w) => w is Container || w is SizedBox,
          ),
        ),
      )
      .map((w) => tester.getRect(find.byWidget(w)))
      .toList();
}

/// The index of the row carrying the only tint of [color], or -1 when there is
/// none. Exactly one tint is expected: this is the assertion's job, not the
/// helper's.
int _tintedRow(WidgetTester tester, Color color) {
  final tinted = _tintedRects(tester, color);
  expect(tinted, hasLength(1), reason: 'expected exactly one $color row');

  return _rowOf(tester, tinted.first);
}

/// Which laid-out row [rect] is, by its top edge.
int _rowOf(WidgetTester tester, Rect rect) {
  final rows = _rowRects(tester);
  for (var i = 0; i < rows.length; i++) {
    if ((rows[i].top - rect.top).abs() < 0.5) {
      return i;
    }
  }

  fail('the rect is not one of the ${rows.length} laid-out rows');
}

/// The row the caret's line *should* be tinted on, or -1 when that line is not
/// rendered and there is therefore no row to tint.
///
/// Computed from the layer's own inputs — the caret's line among the visible
/// line numbers — so it holds whatever the fold did to the caret, which is the
/// fold's business and not this feature's.
int _expectedCaretRow(CodeController controller) {
  final text = controller.code.text;
  final caretLine = controller.code.lines.characterIndexToLineIndex(
    controller.selection.extentOffset.clamp(0, text.length),
  );

  return controller.code.hiddenLineRanges.visibleLineNumbers.toList().indexOf(
    caretLine,
  );
}

/// The row the caret's line actually is tinted on. Exactly one tint is expected,
/// or none at all when the caret's line is not rendered.
int _actualCaretRow(CodeController controller, WidgetTester tester) {
  final expected = _expectedCaretRow(controller);
  if (expected == -1) {
    expect(
      _tintedRects(tester, _tint),
      isEmpty,
      reason: 'the caret\'s line is not rendered, so nothing should be tinted',
    );
    return -1;
  }

  return _tintedRow(tester, _tint);
}

/// The tint is on the caret's line, and on nothing else.
void _expectTintOnCaretRow(CodeController controller, WidgetTester tester) {
  expect(_actualCaretRow(controller, tester), _expectedCaretRow(controller));
}

void main() {
  group('CodeController.currentLineColor', () {
    testWidgets('tints the caret\'s row when it is the only hook set', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        // The caret starts on line 0.
        selection: const TextSelection.collapsed(offset: 0),
      );

      expect(_tintedRow(tester, _tint), 0);

      // The load-bearing assertion, borrowed from #86: the tint is wider than
      // the line's own text by a wide margin, so it is the row and not a
      // glyph-run background.
      final textWidth = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: 'a',
          style: DefaultTextStyle.of(
            tester.element(find.byType(CodeField)),
          ).style,
        ),
      )..layout();
      addTearDown(textWidth.dispose);
      expect(
        _tintedRects(tester, _tint).first.width,
        greaterThan(textWidth.width + 100),
      );
    });

    testWidgets('leaves every other row untilted', (tester) async {
      await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );

      // One tinted row out of four rendered lines — the other three reserve
      // their height without painting, exactly as #86's layer does.
      expect(_rowRects(tester), hasLength(4));
      expect(_tintedRects(tester, _tint), hasLength(1));
    });

    testWidgets('follows the caret when the selection moves', (tester) async {
      final controller = await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );
      expect(_tintedRow(tester, _tint), 0);

      // A caret on line 2, moved the way a real caret move moves it: by
      // assigning a new selection to the TextEditingController.
      controller.selection = const TextSelection.collapsed(offset: 6);
      controller.notifyListeners();
      await tester.pumpAndSettle();

      expect(_tintedRow(tester, _tint), 2);
    });

    testWidgets('follows the caret while typing', (tester) async {
      await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );

      // The real keystroke path: focus the field the way a user does, then
      // type. #113's claim is that the tint follows the caret, and the caret
      // moving through the editor's own input handling is the strongest form of
      // that claim.
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // The tap lands wherever the field was tapped — the centre of the field,
      // which in this four-line fixture is line 2. The tint followed it there.
      final tappedRow = _tintedRow(tester, _tint);
      expect(tappedRow, isNot(0));

      await tester.enterText(find.byType(TextField), 'a\nb');
      await tester.pumpAndSettle();

      // Two lines, so the caret at the end of the new text is on line 1.
      expect(_tintedRow(tester, _tint), 1);
    });

    testWidgets('follows the caret when a line is tapped', (tester) async {
      await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );

      final rows = _rowRects(tester);
      await tester.tapAt(Offset(300, rows[1].center.dy));
      await tester.pumpAndSettle();

      expect(_tintedRow(tester, _tint), 1);
    });

    testWidgets('tints only the caret\'s line when a selection spans several', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        // Anchored on line 0, caret dragged onto line 2.
        selection: const TextSelection(baseOffset: 0, extentOffset: 6),
      );

      // The extent is the line that moved; VSCode highlights the caret's line,
      // and so does this.
      expect(_tintedRow(tester, _tint), 2);
    });

    testWidgets('renders and tints nothing with no selection at all', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // An empty document's value carries the -1 selection sentinel.
      final controller = CodeController(text: '');
      controller.currentLineColor = _tint;

      await tester.pumpWidget(createApp(controller, FocusNode()));
      await tester.pumpAndSettle();

      expect(controller.selection.extentOffset, -1);
      expect(find.byType(LineBackgroundLayer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LineBackgroundLayer),
          matching: find.byWidgetPredicate((w) => w is Container),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'tints the last line when the caret is at the end of the text',
      (tester) async {
        final controller = await _pumpField(
          tester,
          text: _document,
          currentLineColor: _tint,
        );

        // Off the end of the document — a legal index for
        // `characterIndexToLineIndex`, which documents it as "the cursor at the
        // end of the text". It must tint the last line, not throw.
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        controller.notifyListeners();
        await tester.pumpAndSettle();

        expect(_tintedRow(tester, _tint), 3);
      },
    );

    testWidgets('tints nothing when the caret\'s line is no longer rendered', (
      tester,
    ) async {
      final controller = await _pumpField(
        tester,
        text: _foldable,
        currentLineColor: _tint,
        // Inside the block that is about to be folded away.
        selection: const TextSelection.collapsed(offset: 12),
      );

      _expectTintOnCaretRow(controller, tester);

      final block = controller.code.foldableBlocks.firstWhere(
        (b) => b.firstLine == 0,
      );
      controller.foldBlocks([block]);
      await tester.pumpAndSettle();

      // Folding hides lines 1–2 and remaps the caret, so where the tint goes is
      // the fold's business, not this feature's. What is this feature's
      // business — and what is asserted — is that the tint is on the caret's
      // line whenever that line is still rendered, and on nothing at all when
      // it is not. A caret on a hidden line has no row to tint, and the build
      // must not throw either.
      _expectTintOnCaretRow(controller, tester);
    });

    testWidgets('keeps tinting the caret\'s line when a fold opens elsewhere', (
      tester,
    ) async {
      final controller = await _pumpField(
        tester,
        text: _foldable,
        currentLineColor: _tint,
        // Line 3 is outside the block, so folding cannot touch it.
        selection: const TextSelection.collapsed(offset: 16),
      );

      final block = controller.code.foldableBlocks.firstWhere(
        (b) => b.firstLine == 0,
      );
      controller.foldBlocks([block]);
      await tester.pumpAndSettle();

      _expectTintOnCaretRow(controller, tester);
    });

    testWidgets('composes: the host builder wins and the caret still tints', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text: _document,
        lineBackgroundBuilder: (line) => line == 3 ? _hostTint : null,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );

      // Line 3 takes the host's colour, line 0 takes the caret tint, and the
      // remaining rows stay untilted.
      expect(_tintedRow(tester, _hostTint), 3);
      expect(_tintedRow(tester, _tint), 0);
    });

    testWidgets('composes: the host builder wins even on the caret\'s line', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text: _document,
        lineBackgroundBuilder: (line) => line == 0 ? _hostTint : null,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );

      // The caret is on the very line the host coloured, and the host's answer
      // is final — the caret tint must not overwrite it, and must not spill
      // onto another line either.
      expect(_tintedRects(tester, _hostTint), hasLength(1));
      expect(_tintedRects(tester, _tint), isEmpty);
    });

    testWidgets('leaves the field untouched when neither hook is set', (
      tester,
    ) async {
      await _pumpField(tester, text: _document);

      // No tint machinery of any kind reaches the tree: not the layer, and not
      // even the Stack that would hold it. This is #86's invariant, and the
      // caret tint must not break it.
      expect(find.byType(LineBackgroundLayer), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CodeField),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });

    testWidgets('still works when no language is set', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = CodeController(text: _document);
      controller.currentLineColor = _tint;
      controller.selection = const TextSelection.collapsed(offset: 0);

      await tester.pumpWidget(createApp(controller, FocusNode()));
      await tester.pumpAndSettle();

      expect(_tintedRow(tester, _tint), 0);
    });

    testWidgets('re-renders when the colour is reassigned', (tester) async {
      final controller = await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );

      controller.currentLineColor = _hostTint;
      controller.notifyListeners();
      await tester.pumpAndSettle();

      expect(_tintedRects(tester, _tint), isEmpty);
      expect(_tintedRow(tester, _hostTint), 0);
    });

    testWidgets('takes the layer back out of the tree when the colour is '
        'cleared', (tester) async {
      final controller = await _pumpField(
        tester,
        text: _document,
        currentLineColor: _tint,
        selection: const TextSelection.collapsed(offset: 0),
      );
      expect(find.byType(LineBackgroundLayer), findsOneWidget);

      controller.currentLineColor = null;
      controller.notifyListeners();
      await tester.pumpAndSettle();

      // Clearing the only remaining hook puts the field back to its exact
      // default tree — the layer and the Stack that holds it both go, which is
      // the same state as never having had a hook.
      expect(find.byType(LineBackgroundLayer), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CodeField),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });
  });
}
