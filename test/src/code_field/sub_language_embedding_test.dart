// ignore_for_file: discarded_futures

import 'package:highlight/highlight.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/dockerfile.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// #62 — sub-language embedding never highlights.
///
/// `highlight` resolves an embedded sub-language **by name** out of its
/// language registry, so `_processSubLanguage` hands the fragment back as a
/// single plain node whenever that name is not registered.
/// `CodeController` registers the language it is handed under a synthetic
/// `hashCode` key, which leaves every reference unresolved, so markdown's
/// `<b>html</b>`, dart's doc comments, erb's Ruby, dockerfile's `RUN` bodies
/// and every other embedding silently lost their highlighting.
void main() {
  String htmlOf(CodeController controller) =>
      controller.code.visibleHighlighted?.toHtml() ?? '';

  group('Sub-language embedding (#62)', () {
    test('markdown highlights the HTML it embeds', () {
      final controller = CodeController(
        text: 'Some <b>html</b> here.',
        language: markdown,
      );
      addTearDown(controller.dispose);

      final html = htmlOf(controller);

      expect(
        html,
        contains('hljs-tag'),
        reason: 'the embedded <b> tag must be tokenised as XML, was: $html',
      );
      expect(html, contains('<span class="xml">'));
    });

    test('dart highlights a doc comment as markdown', () {
      final controller = CodeController(
        text: '/// Doc with *emphasis* and `code`\nvoid main() {}\n',
        language: dart,
      );
      addTearDown(controller.dispose);

      final html = htmlOf(controller);

      expect(
        html,
        contains('<span class="markdown">'),
        reason: 'the doc comment must be tokenised as markdown, was: $html',
      );
      expect(html, contains('hljs-emphasis'));
      expect(html, contains('hljs-code'));
      // The code outside the comment is still dart.
      expect(html, contains('hljs-keyword'));
    });

    test('dockerfile highlights a RUN body as bash', () {
      // The `starts` branch of the walk: dockerfile's `RUN` switches to a
      // sub-language through a terminal mode rather than `contains`.
      final controller = CodeController(
        text: 'RUN echo "hi" && ls\n',
        language: dockerfile,
      );
      addTearDown(controller.dispose);

      final html = htmlOf(controller);

      expect(
        html,
        contains('<span class="bash">'),
        reason: 'the RUN body must be tokenised as bash, was: $html',
      );
      expect(html, contains('hljs-built_in'));
      expect(html, contains('hljs-string'));
    });

    test('an embedded language outside the bundled set stays plain', () {
      // A mode that embeds a name this package does not bundle still falls
      // back to plaintext exactly as before, so the boundary is honest.
      final embedder = Mode(
        contains: [
          Mode(begin: '<', end: '>', subLanguage: ['not-a-language']),
        ],
      );

      final controller = CodeController(
        text: 'a <b>x</b> b',
        language: embedder,
      );
      addTearDown(controller.dispose);

      expect(htmlOf(controller), 'a &lt;b&gt;x&lt;/b&gt; b');
    });

    test('registering the embedded languages is reversible per language', () {
      final controller = CodeController(
        text: 'Some <b>html</b> here.',
        language: markdown,
      );
      addTearDown(controller.dispose);

      expect(htmlOf(controller), contains('hljs-tag'));

      // Switching away and back must leave the embedding working.
      controller.language = dart;
      controller.language = markdown;

      expect(htmlOf(controller), contains('hljs-tag'));
    });

    test('languageId keeps reporting the language hashCode', () {
      final controller = CodeController(text: 'int a;', language: markdown);
      addTearDown(controller.dispose);

      expect(controller.languageId, markdown.hashCode.toString());
    });

    test('the embedded languages really are in the highlight registry', () {
      final dartController = CodeController(text: '/// doc\n', language: dart);
      addTearDown(dartController.dispose);
      final markdownController = CodeController(
        text: '<b>x</b>',
        language: markdown,
      );
      addTearDown(markdownController.dispose);

      // Reached through the public API, so the assertion does not depend on
      // how the controller stores what it registered.
      final html = highlight.parse('a <b>x</b> b', language: 'md').toHtml();
      expect(html, contains('hljs-tag'));
    });
  });
}
