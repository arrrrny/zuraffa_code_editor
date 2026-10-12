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

/// A comment block, whose kept line ends *inside* a comment — a styled node
/// sits next to the kept line, though the newline that terminates the line is
/// a plain node of its own.
const _commentBlock =
    'class A {\n'
    '  // first comment line\n'
    '  // second comment line\n'
    '  int a;\n'
    '}\n';

/// A fold whose kept line is the last line of the document, and the document
/// has no trailing newline — the one shape that has no terminating newline to
/// splice the marker in front of.
const _noTrailingNewline =
    'class A {\n'
    '  int a;\n'
    '  int b;\n'
    '}';

/// A fold inside a read-only section. The line's own text is painted palled
/// there — the one shape where the terminating node's style differs from the
/// base style, which is what makes the marker's own style observable.
const _readOnlySection =
    'class A {\n'
    '  // [START locked]\n'
    '  void a() {\n'
    '    one();\n'
    '  }\n'
    '  // [END locked]\n'
    '}\n';

/// A document whose last foldable block runs to its end with no trailing
/// newline, so the fold's kept line is the last visible line — the one marker
/// that is appended to the tree rather than spliced. The match the search
/// test looks for sits on the line *above* the fold, which is the only way to
/// have a match at all without the search unfolding the block: a match that
/// overlaps the fold reveals it (`SearchNavigationController`).
const _lastLineFold =
    'class A {}\n'
    'class B {\n'
    '  int b;\n'
    '  int c;\n'
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

    test('A marker after a comment does not come out comment-coloured', () {
      final controller = _controller(_commentBlock);

      // `  // first comment line` / `  // second comment line` is one foldable
      // block, and its kept line ends inside a comment: the comment node sits
      // next to the line, so the marker must not borrow its colour.
      controller.foldAt(1);

      final span = _spanOf(controller);
      expect(
        _plainTextOf(span),
        'class A {\n  // first comment line …\n  int a;\n}\n',
      );
      expect(_markerLeaf(span)!.style, _root);
    });

    test('A marker on a read-only line is not palled', () {
      final controller = CodeController(
        text: _readOnlySection,
        language: java,
        namedSectionParser: const BracketsStartEndNamedSectionParser(),
        readOnlySectionNames: const {'locked'},
      );
      addTearDown(controller.dispose);

      // The kept line is read-only, so every character of it is painted
      // palled. The marker is decoration, not content: it keeps the base
      // style rather than the terminating node's palled one.
      controller.foldAt(2); // `  void a() {`

      final marker = _markerLeaf(_spanOf(controller));
      expect(marker, isNotNull);
      expect(marker!.style, _root);
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

    testWidgets('a match above the fold suppresses the final-line marker', (
      wt,
    ) async {
      final controller = CodeController(text: _lastLineFold, language: java);
      addTearDown(controller.dispose);

      // `class B {` folds to `class B {}`, whose kept line is the *last*
      // visible line — the one marker that is appended to the tree rather than
      // spliced, so the search switch has to hold there too. The match is on
      // the line above the fold, so it leaves the fold closed: a match
      // overlapping it would unfold the block instead.
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

      _searchFor(controller, 'A');
      await wt.pumpAndSettle();

      final span = controller.buildTextSpan(
        context: wt.element(find.byType(EditableText)),
      );

      expect(_markerLeaf(span), isNull);
      expect(
        _leavesOf(span)
            .where((leaf) => leaf.style?.backgroundColor != null)
            .map((leaf) => leaf.text!)
            .join(),
        'A',
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
