import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/code_field/span_builder.dart';
import 'package:zuraffa_code_editor/src/search/settings.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

const _root = TextStyle(color: Color(0xFF000000));
const _string = TextStyle(color: Color(0xFF000001));
const _keyword = TextStyle(color: Color(0xFF000002));
const _comment = TextStyle(color: Color(0xFF000003));

final _theme = CodeThemeData(
  quoteStyle: _string,
  keywordStyle: _keyword,
  commentStyle: _comment,
);

/// The whole of a folded document, in one nested shape, so the fold target is
/// unambiguous and the kept line is unambiguous with it.
const _config =
    'final config = ScraperConfig(\n'
    '  clientType: HttpClientType.crawler,\n'
    '  parsers: [\n'
    '    ParserConfig(\n'
    '      kind: ParserType.jsonLd,\n'
    '    ),\n'
    '  ],\n'
    ');\n';

/// A document whose folded block ends on a line that opens the following
/// block, so the closer is left a row of its own instead of being glued to the
/// kept line (akvelon/flutter-code-editor#213).
const _sharedClosingLine =
    'int factorial(int n){\n'
    '  if(n == 0){\n'
    '    return 0;\n'
    '  }\n'
    '\n'
    '  return n * factorial(n - 1);\n'
    '}void main(){\n'
    '  int num = 5;\n'
    '}\n';

/// Two sibling blocks, so two folds can be open at once without one swallowing
/// the other.
const _twoBlocks =
    'class A {\n'
    '  void a() {\n'
    '    one();\n'
    '  }\n'
    '  void b() {\n'
    '    two();\n'
    '  }\n'
    '}\n';

/// A fold whose kept line is the last line of the document, and the document
/// has no trailing newline — the one shape that has no terminating newline to
/// splice the marker in front of.
const _noTrailingNewline =
    'class A {\n'
    '  int a;\n'
    '  int b;\n'
    '}';

/// Every leaf `TextSpan` of [span] in the order the text is painted.
List<TextSpan> _leavesOf(InlineSpan span) {
  final result = <TextSpan>[];

  void walk(InlineSpan current) {
    if (current is! TextSpan) {
      return;
    }
    if (current.text != null && current.text!.isNotEmpty) {
      result.add(current);
    }
    for (final child in current.children ?? const <InlineSpan>[]) {
      walk(child);
    }
  }

  walk(span);
  return result;
}

/// The painted text of [span], marker included.
String _plainTextOf(InlineSpan span) =>
    _leavesOf(span).map((leaf) => leaf.text!).join();

/// The span the editor renders, folding included.
TextSpan _spanOf(CodeController controller) =>
    SpanBuilder(code: controller.code, theme: _theme, rootStyle: _root).build();

CodeController _controller(String text) {
  final controller = CodeController(text: text, language: java);
  addTearDown(controller.dispose);
  return controller;
}

/// The leaf that carries the marker, or null when the tree carries none.
TextSpan? _markerLeaf(InlineSpan span) {
  for (final leaf in _leavesOf(span)) {
    if (leaf.text!.endsWith(' …')) {
      return leaf;
    }
  }
  return null;
}

List<TextSpan> _markerLeaves(InlineSpan span) =>
    _leavesOf(span).where((leaf) => leaf.text!.contains(' …')).toList();

void main() {
  group('A folded block ends its kept line with an ellipsis.', () {
    test('The kept line carries a trailing marker', () {
      final controller = _controller(_config);

      controller.foldAt(2); // `  parsers: [`

      final plain = _plainTextOf(_spanOf(controller));
      // The marker is on the kept line, not anywhere else.
      expect(plain, '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ], …
);
''');
    });

    test('An unfolded document carries no marker', () {
      final controller = _controller(_config);

      final plain = _plainTextOf(_spanOf(controller));

      expect(plain, _config);
      expect(_markerLeaves(_spanOf(controller)), isEmpty);
    });

    test('Unfolding removes the marker and nothing else', () {
      final controller = _controller(_config);
      final before = _plainTextOf(_spanOf(controller));

      controller.foldAt(2);
      final folded = _plainTextOf(_spanOf(controller));
      expect(folded, isNot(equals(before)));
      expect(folded, contains(' …'));

      controller.unfoldAt(2);
      expect(_plainTextOf(_spanOf(controller)), before);
      expect(_markerLeaves(_spanOf(controller)), isEmpty);
    });

    test('Folding does not touch the editing buffer', () {
      final controller = _controller(_config);

      controller.foldAt(2);

      expect(controller.code.text, _config);
      expect(controller.text, isNot(contains(' …')));
      expect(controller.text, '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ],
);
''');
    });

    test('A keystroke after a fold keeps the marker on the kept line', () {
      final controller = _controller(_config);

      controller.foldAt(2);
      // Put a line above the whole document, so the parse re-runs with a fold
      // still open and every line below it moves down one row.
      controller.selection = const TextSelection.collapsed(offset: 0);
      controller.text = '// c\n${controller.text}';

      final marked = _plainTextOf(
        _spanOf(controller),
      ).split('\n').where((line) => line.contains(' …')).toList();
      expect(marked, ['  parsers: [  ], …']);
    });

    test('The marker rides after a closer that shares the kept row', () {
      final controller = _controller(_config);

      controller.foldAt(3); // `    ParserConfig(`

      expect(_plainTextOf(_spanOf(controller)), '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [
    ParserConfig(    ), …
  ],
);
''');
    });

    test('A closer on its own row gets no marker of its own', () {
      final controller = _controller(_sharedClosingLine);

      // `int factorial(int n){` folds 0..7 and leaves `}void main(){` on a row
      // of its own, because that row is where the next block hangs its toggle.
      controller.foldAt(0);

      expect(_plainTextOf(_spanOf(controller)), '''
int factorial(int n){ …
}void main(){
  int num = 5;
}
''');
    });

    test(
      'The last visible line gets a marker with no newline to splice before',
      () {
        final controller = _controller(_noTrailingNewline);

        controller.foldAt(0);

        expect(controller.text, 'class A {}');
        expect(_plainTextOf(_spanOf(controller)), 'class A {} …');
        expect(_markerLeaves(_spanOf(controller)).length, 1);
      },
    );

    test('Two open folds each carry a marker', () {
      final controller = _controller(_twoBlocks);

      controller.foldAt(1); // `  void a() {`
      controller.foldAt(4); // `  void b() {`

      expect(_plainTextOf(_spanOf(controller)), '''
class A {
  void a() {  } …
  void b() {  } …
}
''');
    });

    test('A fold swallowed by another fold carries no marker', () {
      final controller = _controller(_config);

      controller.foldAt(2); // outer
      controller.foldAt(3); // inner, swallowed: its kept line is hidden

      // Only the outer block's kept line is visible, so only it is marked.
      expect(_markerLeaves(_spanOf(controller)).length, 1);
      expect(_plainTextOf(_spanOf(controller)), '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ], …
);
''');
    });

    test('The marker carries the base style, not the token style', () {
      final controller = _controller(_config);

      controller.foldAt(2);

      // `  ],` is painted in the document style; the marker must not borrow a
      // token colour from whatever it follows, or it reads as part of the code.
      final marker = _markerLeaf(_spanOf(controller));
      expect(marker, isNotNull);
      expect(marker!.style, _root);
      expect(marker.text, ' …');
    });

    test('With no base style the marker falls back to the line style', () {
      final controller = _controller(_config);

      controller.foldAt(2);

      // Flutter always hands `buildTextSpan` a style, so a null root style is
      // not a reachable path; the fallback is what keeps the marker on the
      // line's own metrics if it ever were.
      final leaves = _leavesOf(
        SpanBuilder(
          code: controller.code,
          theme: _theme,
          rootStyle: null,
        ).build(),
      );

      final markerIndex = leaves.indexWhere(
        (leaf) => leaf.text!.contains(' …'),
      );
      expect(markerIndex, isNot(-1));

      // It paints in the style of the text it follows, not in some ambient
      // default that would give it different metrics from the line.
      expect(leaves[markerIndex].style, leaves[markerIndex - 1].style);
    });
  });

  group('The editor renders the marker through buildTextSpan.', () {
    testWidgets('The painted tree of a folded field carries the marker', (
      wt,
    ) async {
      final controller = CodeController(text: _config, language: java);
      addTearDown(controller.dispose);

      controller.foldAt(2);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableText(
              controller: controller,
              focusNode: FocusNode(),
              style: const TextStyle(),
              cursorColor: Colors.black,
              backgroundCursorColor: Colors.black,
            ),
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: wt.element(find.byType(EditableText)),
      );

      expect(_plainTextOf(span), '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ], …
);
''');
      // The marker is a leaf of its own so the caller can see it.
      expect(_markerLeaf(span), isNotNull);
    });
  });

  group('Search matches survive a fold.', () {
    testWidgets('A match after a folded line still lands on its own text', (
      wt,
    ) async {
      final controller = CodeController(text: _twoBlocks, language: java);
      addTearDown(controller.dispose);

      // `  void a() {` is folded, so every match below it sits after a marker
      // in the tree the search builder slices.
      controller.foldAt(1);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableText(
              controller: controller,
              focusNode: FocusNode(),
              style: const TextStyle(),
              cursorColor: Colors.black,
              backgroundCursorColor: Colors.black,
            ),
          ),
        ),
      );

      _searchFor(controller, 'two()');
      await wt.pumpAndSettle();

      final span = controller.buildTextSpan(
        context: wt.element(find.byType(EditableText)),
      );

      // Match offsets are measured against `Code.visibleText`, which has no
      // marker in it: carrying one through the tree would shift the highlight
      // off its text.
      expect(
        _leavesOf(span)
            .where((leaf) => leaf.style?.backgroundColor != null)
            .map((leaf) => leaf.text!)
            .join(),
        'two()',
      );

      controller.dismiss();
      await wt.pumpAndSettle();
    });
  });

  group('The paths that bypass SpanBuilder.', () {
    testWidgets('no ellipsis while an IME composition is active', (wt) async {
      final controller = CodeController(text: _config, language: java);
      addTearDown(controller.dispose);

      controller.foldAt(2);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableText(
              controller: controller,
              focusNode: FocusNode(),
              style: const TextStyle(),
              cursorColor: Colors.black,
              backgroundCursorColor: Colors.black,
            ),
          ),
        ),
      );

      // The composing path builds from the controller's value and never
      // reaches `SpanBuilder`, so the marker is gone while it runs and comes
      // back the moment the composition ends.
      controller.value = TextEditingValue(
        text: controller.text,
        selection: const TextSelection.collapsed(offset: 0),
        composing: const TextRange(start: 0, end: 2),
      );
      await wt.pumpAndSettle();

      expect(
        _markerLeaf(
          controller.buildTextSpan(
            context: wt.element(find.byType(EditableText)),
          ),
        ),
        isNull,
      );

      controller.dismiss();
      await wt.pumpAndSettle();
    });

    testWidgets('no ellipsis when no language is set', (wt) async {
      final controller = CodeController(text: _config);
      addTearDown(controller.dispose);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableText(
              controller: controller,
              focusNode: FocusNode(),
              style: const TextStyle(),
              cursorColor: Colors.black,
              backgroundCursorColor: Colors.black,
            ),
          ),
        ),
      );

      // No language, so no fold machinery and no `SpanBuilder`: the tree is
      // the bare span over the controller's own value.
      expect(controller.code.foldableBlocks, isEmpty);
      expect(
        _markerLeaf(
          controller.buildTextSpan(
            context: wt.element(find.byType(EditableText)),
          ),
        ),
        isNull,
      );
    });
  });
}

/// Types the pattern into the search overlay, the way the widget does.
void _searchFor(CodeController controller, String pattern) {
  controller.showSearch();
  controller.searchController.settingsController.patternController.text =
      pattern;
  controller.searchController.settingsController.value = SearchSettings(
    isCaseSensitive: true,
    isRegExp: false,
    pattern: pattern,
  );
}
