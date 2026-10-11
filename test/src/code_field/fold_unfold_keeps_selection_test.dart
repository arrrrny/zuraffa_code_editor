import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';
import '../common/snippets.dart';

const _source = '''
private class MyClass {
  void method1() {
    return;
  }

  void method2() {
    return;
  }
}
''';

const _otherSource = '''
class Other {
  int method() {
    return 1;
  }

  int another() {
    return 2;
  }
}
''';

void main() {
  group('CodeController. Fold and unfold preserve the selection.', () {
    test('a selection inside the folded block survives the round trip', () {
      final controller = createController(_source);

      // `    return;` and the closing brace — the block foldAt(1) hides.
      final start = controller.text.indexOf('    return;');
      final selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 15,
      );

      controller.selection = selection;
      controller.foldAt(1);
      final folded = controller.selection;

      controller.unfoldAt(1);

      expect(controller.code.foldedBlocks, isEmpty);
      expect(
        folded,
        const TextSelection(baseOffset: 42, extentOffset: 45),
        reason: 'while folded, only the visible remainder can be shown',
      );
      expect(controller.selection, selection);
    });

    test('a caret inside the folded block survives the round trip', () {
      final controller = createController(_source);

      final caret = controller.text.indexOf('    return;') + 4;
      controller.selection = TextSelection.collapsed(offset: caret);

      controller.foldAt(1);
      final folded = controller.selection;

      controller.unfoldAt(1);

      expect(folded.start, 42, reason: 'pulled to the fold marker');
      expect(controller.selection.start, caret);
    });

    test('a selection straddling the fold survives the round trip', () {
      final controller = createController(_source);

      // From the class header through into method1's body.
      final end = controller.text.indexOf('  void method1() {') + 20;
      final selection = TextSelection(baseOffset: 0, extentOffset: end);

      controller.selection = selection;
      controller.foldAt(1);
      final folded = controller.selection;

      controller.unfoldAt(1);

      expect(folded.end, 42, reason: 'clamped to the fold marker');
      expect(controller.selection, selection);
    });

    test('a selection outside the folded block is not resurrected', () {
      final controller = createController(_source);

      // The second `return;` sits past method1's closing brace.
      final start = controller.text.indexOf('    return;', 60);
      final selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 11,
      );

      controller.selection = selection;
      controller.foldAt(1);
      final folded = controller.selection;

      controller.unfoldAt(1);

      expect(
        folded,
        isNot(selection),
        reason: 'the fold shifted the visible text',
      );
      expect(folded.start, start - 13);
      expect(controller.selection, selection);
    });

    test('moving the selection after the fold forgets the folded one', () {
      final controller = createController(_source);

      final start = controller.text.indexOf('    return;');
      controller.selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 15,
      );

      controller.foldAt(1);

      // The user points somewhere else while the block is folded. The offset
      // is in the visible text, which is what the field is showing now.
      final moved = controller.text.indexOf('  void method2() {') + 4;
      controller.selection = TextSelection.collapsed(offset: moved);

      controller.unfoldAt(1);

      expect(controller.selection.start, isNot(start + 15));
      expect(controller.text, startsWith('private class MyClass {'));
    });

    test('unfolding another block does not resurrect the folded selection', () {
      final controller = createController(TwoMethodsSnippet.full);

      final start = controller.text.indexOf('    return;\n  }');
      controller.selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 12,
      );

      controller.foldAt(2);
      final folded = controller.selection;

      // Unfold a later block, not the one that hid the selection.
      controller.unfoldAt(7);

      expect(controller.code.foldedBlocks, isNotEmpty);
      expect(controller.selection, folded);
    });

    test('the remembered selection does not leak into a plain keystroke', () {
      final controller = createController(_source);

      final start = controller.text.indexOf('    return;');
      controller.selection = TextSelection.collapsed(offset: start);
      controller.foldAt(1);
      controller.unfoldAt(1);

      // A keystroke now: the restored selection is the one that shifts.
      final before = controller.text;
      controller.value = TextEditingValue(
        text: '${before.substring(0, start)}x${before.substring(start)}',
        selection: TextSelection.collapsed(offset: start + 1),
      );

      expect(controller.selection.start, start + 1);
      expect(controller.fullText, contains('x    return;'));
    });

    test('replacing the full text forgets the folded selection', () {
      final controller = createController(_source);

      final start = controller.text.indexOf('    return;');
      final selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 15,
      );

      controller.selection = selection;
      controller.foldAt(1);

      // The document is replaced while the block is still folded: the
      // remembered offsets belong to the old document, so the next fold must
      // neither cut nor restore them.
      controller.fullText = _otherSource;
      controller.foldAt(1);

      expect(
        controller.selection,
        isNot(selection),
        reason: 'the stale offsets refer to the replaced document',
      );

      controller.unfoldAt(1);

      expect(controller.fullText, _otherSource);
      expect(controller.selection, isNot(selection));
    });

    test('indenting the selected lines forgets the folded selection', () {
      final controller = createController(_source);

      final start = controller.text.indexOf('    return;');
      final selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 15,
      );

      controller.selection = selection;
      controller.foldAt(1);
      controller.indentSelection();
      final afterIndent = controller.selection;

      controller.unfoldAt(1);

      expect(
        controller.selection,
        isNot(selection),
        reason: 'the indent re-established the selection in the visible text',
      );
      expect(controller.selection, afterIndent);
    });
  });
}
