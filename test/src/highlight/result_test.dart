import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart';
import 'package:zuraffa_code_editor/src/highlight/result.dart';

void main() {
  group('MyResult.forEachNode', () {
    test('walks depth-first and tracks per-value line/character offsets', () {
      final result = Result(
        nodes: [
          Node(value: 'ab\nc'),
          Node(
            children: [
              Node(value: 'de'),
              Node(value: '\nf'),
            ],
          ),
        ],
      );

      final visited = <List<dynamic>>[];
      result.forEachNode((node, lineIndex, characterIndex) {
        visited.add([node.value, lineIndex, characterIndex]);
      });

      expect(visited, [
        ['ab\nc', 0, 0],
        [null, 1, 4],
        ['de', 1, 4],
        ['\nf', 1, 6],
      ]);
    });

    test('does nothing when nodes is null', () {
      final result = Result(nodes: null);
      var calls = 0;
      result.forEachNode((_, _, _) => calls++);
      expect(calls, 0);
    });
  });

  group('MyResult.forEachTopLevelNode', () {
    test('uses descendant counts for offsets and skips children', () {
      final result = Result(
        nodes: [
          Node(value: 'ab\nc'),
          Node(children: [Node(value: 'de\nf')]),
        ],
      );

      final visited = <List<dynamic>>[];
      result.forEachTopLevelNode((node, lineIndex, characterIndex) {
        visited.add([node.value, lineIndex, characterIndex]);
      });

      expect(visited, [
        ['ab\nc', 0, 0],
        [null, 1, 4],
      ]);
    });

    test('iterates an empty list when nodes is null', () {
      final result = Result(nodes: null);
      var calls = 0;
      result.forEachTopLevelNode((_, _, _) => calls++);
      expect(calls, 0);
    });
  });

  group('MyResult.splitLines', () {
    test('splits multi-line nodes into one node per line', () {
      final result = Result(
        nodes: [
          Node(children: [Node(value: 'a\nb\nc')]),
        ],
      );

      final split = result.splitLines();

      expect(split.nodes!.single.children!.map((n) => n.value).toList(), [
        'a\n',
        'b\n',
        'c',
      ]);
    });

    test('keeps single-line nodes intact', () {
      final result = Result(nodes: [Node(value: 'abc')]);

      final split = result.splitLines();

      expect(split.nodes!.map((n) => n.value).toList(), ['abc']);
    });

    test('keeps null nodes null', () {
      final split = Result(nodes: null).splitLines();
      expect(split.nodes, isNull);
    });
  });

  group('MyResult.copyWith', () {
    test('overrides only the given fields', () {
      final original = Result(
        relevance: 1,
        nodes: [Node(value: 'a')],
        language: 'dart',
      );

      final copy = original.copyWith(relevance: 7);

      expect(copy.relevance, 7);
      expect(copy.nodes, same(original.nodes));
      expect(copy.language, 'dart');
    });

    test('null arguments keep the original values', () {
      final original = Result(relevance: 3, language: 'dart');

      final copy = original.copyWith();

      expect(copy.relevance, 3);
      expect(copy.language, 'dart');
    });
  });
}
