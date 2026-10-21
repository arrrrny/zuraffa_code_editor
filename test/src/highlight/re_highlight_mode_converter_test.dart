import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart' as hl;
import 'package:highlight/languages/dart.dart' as hl_dart;
import 'package:re_highlight/re_highlight.dart' as re;

import 'package:zuraffa_code_editor/src/highlight/re_highlight_mode_converter.dart';

void main() {
  group('ReHighlightModeConverter', () {
    test('keeps the scope a mode names', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(hl_dart.dart);

      final stringMode = converted.refs!['~contains~0']! as re.Mode;
      expect(stringMode.scope, 'string');
    });

    test('keeps the keywords of a mode', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(hl_dart.dart);

      final keywords = converted.keywords as Map<String, dynamic>;
      expect(keywords['keyword'], contains('abstract'));
      expect(keywords['built_in'], contains('Duration'));
    });

    test('converts the modes a mode contains', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(hl_dart.dart);

      expect(converted.contains, isNotNull);
      expect(converted.contains, isNotEmpty);
      expect(converted.contains!.every((mode) => mode is re.Mode), isTrue);
    });

    test('converts the refs a mode carries', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(hl_dart.dart);

      expect(converted.refs, isNotNull);
      expect(converted.refs!['~contains~0'], isA<re.Mode>());
    });

    test('converts a mode without refs or contains', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(
        hl.Mode(className: 'string', begin: '"', end: '"'),
      );

      expect(converted.scope, 'string');
      expect(converted.begin, '"');
      expect(converted.end, '"');
      expect(converted.refs, isNull);
      expect(converted.contains, isNull);
    });

    test('the converted grammar highlights like the original one', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(hl_dart.dart);

      final highlight = re.Highlight();
      highlight.registerLanguage('dart', converted);
      final result = highlight.highlight(
        code: 'void main() { print("hi"); }',
        language: 'dart',
      );

      final scopes = <String>[];
      result.render(_ScopeCollector(scopes));

      expect(scopes, contains('keyword'));
      expect(scopes, contains('string'));
    });

    test('a converted grammar is converted only once', () {
      final converter = ReHighlightModeConverter();

      final first = converter.convert(hl_dart.dart);
      final second = converter.convert(hl_dart.dart);

      expect(identical(first, second), isTrue);
    });

    test('keeps the keyword pattern of a mode', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(
        hl.Mode(keywords: {r'$pattern': r'\w+', 'keyword': 'if else'}),
      );

      final keywords = converted.keywords as Map<String, dynamic>;
      expect(keywords[r'$pattern'], r'\w+');
      expect(keywords['keyword'], ['if', 'else']);
    });

    test('keeps a keyword list of a mode', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(
        hl.Mode(
          keywords: {
            'keyword': ['if', '', 'else'],
          },
        ),
      );

      final keywords = converted.keywords as Map<String, dynamic>;
      expect(keywords['keyword'], ['if', 'else']);
    });

    test('keeps a keyword of a type it does not know', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(hl.Mode(keywords: {'keyword': 42}));

      final keywords = converted.keywords as Map<String, dynamic>;
      expect(keywords['keyword'], 42);
    });

    test('keeps a keyword list that is not a map', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(
        hl.Mode(keywords: ['if', '', 'else']),
      );

      expect(converted.keywords, ['if', 'else']);
    });

    test('drops the empty slot of a list of modes', () {
      final converter = ReHighlightModeConverter();
      final converted = converter.convert(
        hl.Mode(
          contains: [
            null,
            hl.Mode(className: 'string'),
          ],
        ),
      );

      expect(converted.contains, hasLength(1));
      expect(converted.contains!.single.scope, 'string');
    });
  });
}

/// Collects the scopes of a highlighted document.
class _ScopeCollector implements re.HighlightRenderer {
  _ScopeCollector(this.scopes);

  final List<String> scopes;

  @override
  void addText(String text) {}

  @override
  void openNode(re.DataNode node) {
    final scope = node.scope;
    if (scope != null) {
      scopes.add(scope);
    }
  }

  @override
  void closeNode(re.DataNode node) {}
}
