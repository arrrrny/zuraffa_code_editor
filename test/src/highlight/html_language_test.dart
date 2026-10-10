import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart' show Node, Result;
import 'package:highlight/languages/xml.dart';

import '../common/create_app.dart';

/// A representative HTML document: a doctype, an element carrying a quoted and
/// a bare attribute value, a comment, text, a nested element and an entity
/// reference.
const _html =
    '<!DOCTYPE html>\n'
    '<div class="a" id=b><!-- note -->hi</div>\n'
    '<p>&amp; text</p>\n';

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
///
/// Nodes without a class hold the literal text between the classified runs, so
/// dropping them leaves the highlighting itself — the thing this test pins.
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

/// Every node value in document order, which must rebuild the source exactly.
String _plainText(Result result) {
  final buffer = StringBuffer();

  void walk(List<Node> nodes) {
    for (final node in nodes) {
      buffer.write(node.value ?? '');
      for (final child in node.children ?? const <Node>[]) {
        walk([child]);
      }
    }
  }

  walk(result.nodes ?? const <Node>[]);
  return buffer.toString();
}

/// HTML has no mode of its own in `highlight`; the `xml` mode is what
/// highlights it. See
/// [arrrrny/zuraffa_code_editor#40](https://github.com/arrrrny/zuraffa_code_editor/issues/40).
void main() {
  group('HTML highlighting through CodeController', () {
    testWidgets('classifies the doctype, tags, element names, attributes, '
        'values, comments and entities', (wt) async {
      final controller = await pumpController(wt, _html, language: xml);

      expect(_classified(controller.code.highlighted!), [
        ('meta', '<!DOCTYPE html>'),
        ('meta-keyword', 'html'),
        ('tag', '<div class="a" id=b>'),
        ('name', 'div'),
        ('attr', 'class'),
        ('string', '"a"'),
        ('attr', 'id'),
        ('string', 'b'),
        ('comment', '<!-- note -->'),
        ('tag', '</div>'),
        ('name', 'div'),
        ('tag', '<p>'),
        ('name', 'p'),
        ('symbol', '&amp;'),
        ('tag', '</p>'),
        ('name', 'p'),
      ]);
    });

    testWidgets('keeps every character of the source', (wt) async {
      final controller = await pumpController(wt, _html, language: xml);

      expect(_plainText(controller.code.highlighted!), _html);
    });
  });

  group('highlight xml mode', () {
    // The premise: `html` is an alias of `xml`, never a mode of its own, which
    // is why the example's `html` entry and the README both point at `xml`.
    // If a future `highlight` release adds a real `html` mode, repoint them.
    test('lists html among its aliases', () {
      expect(xml.aliases, contains('html'));
    });
  });
}
