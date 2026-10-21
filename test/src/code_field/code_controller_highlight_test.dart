import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

void main() {
  group('the highlight of the controller', () {
    test('it is off by default', () {
      final controller = CodeController(text: 'void main() {}', language: java);

      expect(controller.highlightEnabled, isFalse);
      expect(controller.code.visibleHighlighted, isNull);

      controller.dispose();
    });

    test('turning it on parses the document and notifies', () {
      final controller = CodeController(text: 'void main() {}', language: java);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.highlightEnabled = true;

      expect(controller.highlightEnabled, isTrue);
      expect(controller.code.visibleHighlighted, isNotNull);
      expect(notified, 1);

      controller.dispose();
    });

    test('turning it on when it is on changes nothing', () {
      final controller = CodeController(
        text: 'void main() {}',
        language: java,
        highlightEnabled: true,
      );
      var notified = 0;
      controller.addListener(() => notified++);

      controller.highlightEnabled = true;

      expect(notified, 0);

      controller.dispose();
    });

    test('the silent setter changes the code without notifying', () {
      final controller = CodeController(text: 'void main() {}', language: java);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.setHighlightEnabledSilently(true);

      expect(controller.highlightEnabled, isTrue);
      expect(controller.code.visibleHighlighted, isNotNull);
      expect(notified, 0);

      controller.dispose();
    });
  });

  group('the text parsers of the languages', () {
    test('yaml is parsed by its indentation', () {
      final controller = CodeController(
        text: 'root:\n  child: 1\n  other: 2\n',
        language: yaml,
      );

      expect(controller.code.foldableBlocks, isNotEmpty);

      controller.dispose();
    });
  });

  group('the disposed controller', () {
    test('it knows that it is disposed', () {
      final controller = CodeController(text: 'a');

      expect(controller.isDisposed, isFalse);
      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });
  });
}
