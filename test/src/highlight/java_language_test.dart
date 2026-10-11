import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart' show Mode, Node, Result;
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/src/highlight/mode_patches.dart';

import '../common/create_app.dart';

/// A java file the reported defects are in: a `#` on a line of its own, and a
/// triple-quoted string literal spanning lines.
const _java =
    'package a;\n'
    '\n'
    'import java.util.List;\n'
    '\n'
    'public class A {\n'
    '  private String s = """\n'
    'multiline\n'
    '""";\n'
    '}\n'
    '#\n';

/// Everything a classified node spans — its own text plus its descendants'.
///
/// `highlight` puts the matched text of a run in the run's *children*, leaving
/// the classified node itself without a value, so a node's own `value` alone
/// says nothing about what it covers.
String _spans(Node node) {
  final buffer = StringBuffer(node.value ?? '');
  for (final child in node.children ?? const <Node>[]) {
    buffer.write(_spans(child));
  }
  return buffer.toString();
}

/// Every node that carries a class, depth-first, as `(className, spannedText)`.
List<(String, String)> _classified(Result result) {
  final classified = <(String, String)>[];
  void walk(List<Node> nodes) {
    for (final node in nodes) {
      if (node.className != null) {
        classified.add((node.className!, _spans(node)));
      }
      for (final child in node.children ?? const <Node>[]) {
        walk([child]);
      }
    }
  }

  walk(result.nodes ?? const <Node>[]);
  return classified;
}

void main() {
  group('Java highlighting through CodeController', () {
    // The shipped java mode's `class` run carries a trailing space — its `end`
    // is `[{;=]` with `excludeEnd`, so the space before the brace stays inside
    // the run — and it re-classifies its own keyword and title as children.
    // Both are pinned rather than filtered out: they are what the parse
    // produces, and a change in them is a change in the highlighting.
    testWidgets('classifies the document around a # and a triple-quoted '
        'string', (wt) async {
      final controller = await pumpController(wt, _java, language: java);

      expect(_classified(controller.code.highlighted!), [
        ('keyword', 'package'),
        ('keyword', 'import'),
        ('keyword', 'public'),
        ('class', 'class A '),
        ('keyword', 'class'),
        ('title', 'A'),
        ('keyword', 'private'),
        ('string', '"""\nmultiline\n"""'),
      ]);
    });

    testWidgets('keeps every character of the source', (wt) async {
      final controller = await pumpController(wt, _java, language: java);

      final plain = StringBuffer();
      void walk(List<Node> nodes) {
        for (final node in nodes) {
          plain.write(node.value ?? '');
          for (final child in node.children ?? const <Node>[]) {
            walk([child]);
          }
        }
      }

      walk(controller.code.highlighted!.nodes ?? const <Node>[]);
      expect(plain.toString(), _java);
    });

    testWidgets('a # outside a string or a comment keeps the rest of the '
        'document highlighted', (wt) async {
      final controller = await pumpController(
        wt,
        'public class A {\n}\n#\n',
        language: java,
      );

      expect(_classified(controller.code.highlighted!), [
        ('keyword', 'public'),
        ('class', 'class A '),
        ('keyword', 'class'),
        ('title', 'A'),
      ]);
    });

    testWidgets('a # inside a string or a comment is not markup', (wt) async {
      final controller = await pumpController(
        wt,
        '// # note\nString s = "#";\n',
        language: java,
      );

      expect(_classified(controller.code.highlighted!), [
        ('comment', '// # note'),
        ('string', '"#"'),
      ]);
    });

    testWidgets('an unterminated triple-quoted string leaves the document '
        'highlighted up to it', (wt) async {
      final controller = await pumpController(
        wt,
        'public class A {\n  String s = """\n',
        language: java,
      );

      expect(_classified(controller.code.highlighted!), [
        ('keyword', 'public'),
        ('class', 'class A '),
        ('keyword', 'class'),
        ('title', 'A'),
        ('string', '"""\n'),
      ]);
    });

    testWidgets('a document without the defects highlights exactly as the '
        'shipped mode does', (wt) async {
      final source = 'public class A {\n  void m() {}\n}\n';
      final controller = await pumpController(wt, source, language: java);

      expect(_classified(controller.code.highlighted!), [
        ('keyword', 'public'),
        ('class', 'class A '),
        ('keyword', 'class'),
        ('title', 'A'),
        ('function', 'void m() '),
        ('keyword', 'void'),
        ('title', 'm'),
        ('params', '()'),
      ]);
    });
  });

  group('modeToRegister', () {
    test('hands back the java mode it was given a repaired copy for', () {
      expect(modeToRegister(java), isNot(same(java)));
    });

    test('leaves every other mode exactly as it was supplied', () {
      final other = Mode(keywords: 'a b');

      expect(modeToRegister(other), same(other));
    });
  });
}
