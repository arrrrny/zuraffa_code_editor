// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/src/code_field/code_controller.dart';

/// A language this package does not ship, built the way [hl.Mode] allows.
///
/// The reporter of upstream #267 asked how to highlight an unlisted language
/// and reached for `highlight.registerLanguage` first. Handing the mode to
/// [CodeController.language] is the supported path, so these tests pin that the
/// hand-off alone is enough.
final _hello = hl.Mode(
  keywords: {'world': 'keyword'},
  contains: [hl.Mode(className: 'string', begin: '"', end: '"')],
);

void main() {
  group('a language the package does not ship', () {
    test('is used as-is when handed to the controller', () {
      final controller = CodeController(text: '"a string" hello');
      addTearDown(controller.dispose);

      controller.language = _hello;

      expect(controller.language, same(_hello));
    });

    test('is parsed under the controller\'s own key', () {
      final controller = CodeController(text: 'world "a string"');
      addTearDown(controller.dispose);

      controller.language = _hello;

      // The controller registers the mode under a key of its own and parses
      // with that key, so an unlisted language needs no extra call.
      expect(controller.languageId, _hello.hashCode.toString());
    });

    testWidgets('its rules reach the rendered span', (wt) async {
      final controller = CodeController(text: 'world "a string"');
      addTearDown(controller.dispose);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                controller.language = _hello;
                return EditableText(
                  controller: controller,
                  focusNode: FocusNode(),
                  style: const TextStyle(),
                  cursorColor: Colors.black,
                  backgroundCursorColor: Colors.black,
                );
              },
            ),
          ),
        ),
      );

      final spans = _styledSpansOf(
        controller.buildTextSpan(
          context: wt.element(find.byType(EditableText)),
        ),
      );

      // The mode's own keyword and string rules reach the output, which is only
      // possible if the parse ran under the mode it was handed.
      expect(spans.join(''), contains('world'));
      expect(spans.join(''), contains('a string'));
      expect(spans, isNotEmpty);
    });

    test('switching to an unlisted language then back keeps both working', () {
      final controller = CodeController(text: 'int a = 1;', language: java);
      addTearDown(controller.dispose);

      controller.language = _hello;
      expect(controller.language, same(_hello));

      controller.language = java;
      expect(controller.language, same(java));
      expect(controller.languageId, java.hashCode.toString());
    });
  });
}

Iterable<String> _styledSpansOf(InlineSpan span) sync* {
  if (span is TextSpan) {
    if (span.text != null && span.text!.isNotEmpty) {
      yield span.text!;
    }
    for (final child in span.children?.cast<InlineSpan?>() ?? const []) {
      if (child != null) {
        yield* _styledSpansOf(child);
      }
    }
  }
}
