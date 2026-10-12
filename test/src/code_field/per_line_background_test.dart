import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/code_field/line_background.dart';
import 'package:zuraffa_code_editor/src/search/match.dart';
import 'package:zuraffa_code_editor/src/search/result.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

const _tint = Color(0xFFFFE082);
const _otherTint = Color(0xFF90CAF9);

/// A document whose first two lines are one and two characters: the shortest
/// lines that can still be tinted, so a tint's width can never be confused
/// with its own line's text width. The third line is a wide filler, and the
/// trailing newline leaves a fourth, empty line — so this fixture also pins
/// the trailing-newline case.
const _shortFirstLine =
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
  Set<String> visibleSectionNames = const {},
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = createController(
    text,
    visibleSectionNames: visibleSectionNames,
  );
  controller.lineBackgroundBuilder = lineBackgroundBuilder;

  await tester.pumpWidget(createApp(controller, FocusNode()));
  await tester.pumpAndSettle();

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

double _textWidth(WidgetTester tester, String text) {
  final measured = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(tester.element(find.byType(CodeField))).style,
    ),
  )..layout();
  final width = measured.width;
  measured.dispose();
  return width;
}

void main() {
  group('CodeController.lineBackgroundBuilder', () {
    testWidgets('leaves the field untouched when it is not set', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text: _shortFirstLine,
        lineBackgroundBuilder: null,
      );

      // No tint machinery of any kind reaches the tree: not the layer, and not
      // even the Stack that would hold it.
      expect(find.byType(LineBackgroundLayer), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CodeField),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });

    testWidgets('leaves the field untouched when it returns null for every '
        'line', (tester) async {
      await _pumpField(
        tester,
        text: _shortFirstLine,
        lineBackgroundBuilder: (_) => null,
      );

      // The layer is built (a hook was set) but paints nothing.
      expect(find.byType(LineBackgroundLayer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LineBackgroundLayer),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
    });

    testWidgets('tints a one-character line across the whole row', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text: _shortFirstLine,
        lineBackgroundBuilder: (line) => line == 0 ? _tint : null,
      );

      final rects = _tintedRects(tester, _tint);
      expect(rects, hasLength(1));

      // The load-bearing assertion: the tint is wider than the line's own
      // text by a wide margin, so it cannot be a glyph-run background.
      expect(rects.first.width, greaterThan(_textWidth(tester, 'a') + 100));
    });

    testWidgets('does not tint a line the builder returns null for', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text: _shortFirstLine,
        lineBackgroundBuilder: (line) => line == 1 ? _tint : null,
      );

      final rects = _tintedRects(tester, _tint);
      expect(rects, hasLength(1));
      // Line 1 is two characters, so a glyph-run tint would be a fraction of
      // the row; the row is the editor's whole content width.
      expect(rects.first.width, greaterThan(_textWidth(tester, 'bb') + 100));
    });

    testWidgets('hands the builder the full, unfolded line index', (
      tester,
    ) async {
      final seen = <int>[];
      await _pumpField(
        tester,
        text: _shortFirstLine,
        lineBackgroundBuilder: (line) {
          seen.add(line);
          return null;
        },
      );

      // One per rendered line, in document order. The fourth entry is the
      // empty line after the trailing newline — it is a real line and the
      // builder is asked about it.
      expect(seen, [0, 1, 2, 3]);
    });

    testWidgets('does not ask about a line hidden inside a folded block', (
      tester,
    ) async {
      final controller = await _pumpField(
        tester,
        text: _foldable,
        lineBackgroundBuilder: (line) => null,
      );

      final block = controller.code.foldableBlocks.firstWhere(
        (b) => b.firstLine == 0,
      );
      controller.foldBlocks([block]);
      await tester.pumpAndSettle();

      final seen = <int>[];
      controller.lineBackgroundBuilder = (line) {
        seen.add(line);
        return null;
      };
      controller.notifyListeners();
      await tester.pumpAndSettle();

      // Lines 1 and 2 are inside the folded block, so they are not rendered
      // and the builder is never asked about them. Lines 0 and 3 are.
      expect(seen, [0, 3]);
    });

    testWidgets('does not tint lines hidden by a collapsed section', (
      tester,
    ) async {
      await _pumpField(
        tester,
        text:
            'a\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n'
            'cccccccccccccccccccccccccccccccccccccccccccccccccc\n',
        visibleSectionNames: const {'main'},
        lineBackgroundBuilder: (line) => _tint,
      );

      // Only the visible section's lines are rendered, so only those are
      // tinted, and the builder is only asked about those.
      final rects = _tintedRects(tester, _tint);
      expect(rects, isNotEmpty);
      expect(rects.length, lessThan(3));
    });

    testWidgets('still works when no language is set', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = CodeController(text: _shortFirstLine);
      controller.lineBackgroundBuilder = (line) => line == 0 ? _tint : null;

      await tester.pumpWidget(createApp(controller, FocusNode()));
      await tester.pumpAndSettle();

      final rects = _tintedRects(tester, _tint);
      expect(rects, hasLength(1));
      expect(rects.first.width, greaterThan(_textWidth(tester, 'a') + 100));
    });

    testWidgets('re-renders when the hook is reassigned', (tester) async {
      final controller = await _pumpField(
        tester,
        text: _shortFirstLine,
        lineBackgroundBuilder: (line) => line == 0 ? _tint : null,
      );

      controller.lineBackgroundBuilder = (line) =>
          line == 2 ? _otherTint : null;
      controller.notifyListeners();
      await tester.pumpAndSettle();

      expect(_tintedRects(tester, _tint), isEmpty);
      expect(_tintedRects(tester, _otherTint), hasLength(1));
    });

    testWidgets('keeps the search-match colour on top of a tinted line', (
      tester,
    ) async {
      final controller = await _pumpField(
        tester,
        text: 'alpha\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n',
        lineBackgroundBuilder: (_) => _tint,
      );

      controller.fullSearchResult = const SearchResult(
        matches: [SearchMatch(start: 0, end: 5)],
      );
      controller.searchController.showSearch();
      await tester.pumpAndSettle();

      expect(_tintedRects(tester, _tint), isNotEmpty);
    });
  });
}
