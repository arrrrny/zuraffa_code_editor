import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart' show java;
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Covers CodeController's text-editing API: the cursor/insertion helpers, the
/// key actions and the autocomplete-insert path. All of it is public API that
/// consumers call directly, yet none of it was covered.
CodeController _makeController(String text) {
  return CodeController(
    text: text,
    language: java,
    namedSectionParser: const BracketsStartEndNamedSectionParser(),
  );
}

void main() {
  // PopupController.show schedules a post-frame callback.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeController.setCursor', () {
    test('collapses the selection at the given offset', () {
      final controller = _makeController('int a;');
      addTearDown(controller.dispose);

      controller.setCursor(4);

      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });

    test('rejects an offset past the end of the text', () {
      final controller = _makeController('ab');
      addTearDown(controller.dispose);

      // TextEditingController refuses a selection that does not fit the text.
      expect(() => controller.setCursor(99), throwsAssertionError);
    });
  });

  group('CodeController.insertStr', () {
    test('inserts at the cursor and moves the selection past it', () {
      final controller = _makeController('int a;');
      addTearDown(controller.dispose);
      controller.setCursor(0);

      controller.insertStr('void ');

      expect(controller.text, 'void int a;');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    });

    test('replaces the current selection', () {
      final controller = _makeController('int a;');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 4,
      );

      controller.insertStr('long');

      // 'int ' is the replaced range, so the space after it is gone too.
      expect(controller.text, 'longa;');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });
  });

  group('CodeController.removeChar', () {
    test('removes the character before the cursor', () {
      final controller = _makeController('abcd');
      addTearDown(controller.dispose);
      controller.setCursor(2);

      controller.removeChar();

      expect(controller.text, 'acd');
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
    });

    test('is a no-op at the start of the text', () {
      final controller = _makeController('abcd');
      addTearDown(controller.dispose);
      controller.setCursor(0);

      controller.removeChar();

      expect(controller.text, 'abcd');
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
    });
  });

  group('CodeController.removeSelection', () {
    test('removes the selected range', () {
      final controller = _makeController('abcd');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 2,
      );

      controller.removeSelection();

      expect(controller.text, 'cd');
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
    });
  });

  group('CodeController.backspace', () {
    test('removes the selection when one is active', () {
      final controller = _makeController('abcd');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 3,
      );

      controller.backspace();

      expect(controller.text, 'ad');
    });

    test('removes one character when the selection is collapsed', () {
      final controller = _makeController('abcd');
      addTearDown(controller.dispose);
      controller.setCursor(2);

      controller.backspace();

      expect(controller.text, 'acd');
    });
  });

  group('CodeController.onKey with the autocomplete popup open', () {
    testWidgets('arrow up and arrow down are handled by the popup', (wt) async {
      final controller = _makeController('');
      addTearDown(controller.dispose);

      // The popup scrolls by jumping inside the suggestions list, so the list
      // has to be mounted for the arrow path to be reachable.
      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScrollablePositionedList.builder(
              itemScrollController:
                  controller.popupController.itemScrollController,
              itemPositionsListener:
                  controller.popupController.itemPositionsListener,
              itemCount: 3,
              itemBuilder: (context, index) => const SizedBox(height: 40),
            ),
          ),
        ),
      );

      controller.popupController.show(['one', 'two', 'three']);
      await wt.pump();
      expect(controller.popupController.shouldShow, isTrue);

      controller.onKey(
        const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.arrowDown,
          physicalKey: PhysicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      );
      expect(controller.popupController.selectedIndex, 1);

      controller.onKey(
        const KeyDownEvent(
          logicalKey: LogicalKeyboardKey.arrowUp,
          physicalKey: PhysicalKeyboardKey.arrowUp,
          timeStamp: Duration.zero,
        ),
      );
      expect(controller.popupController.selectedIndex, 0);
    });
  });

  group('CodeController.generateSuggestions', () {
    test('hides the popup when the cursor has no word prefix', () async {
      final controller = _makeController('int a;');
      addTearDown(controller.dispose);
      controller.popupController.show(['int']);
      controller.setCursor(0);

      await controller.generateSuggestions();

      expect(controller.popupController.shouldShow, isFalse);
    });

    test('shows the popup for a known keyword prefix', () async {
      // 'pub' is a partial java keyword: it is suggested, unlike the full word
      // at the cursor, which the value setter blacklists.
      final controller = _makeController('pub');
      addTearDown(controller.dispose);
      controller.setCursor(3);

      await controller.generateSuggestions();

      expect(controller.popupController.shouldShow, isTrue);
      expect(controller.popupController.suggestions, contains('public'));
    });
  });

  group('CodeController.insertSelectedWord', () {
    test('hides the popup when there is no word at the cursor', () async {
      final controller = _makeController('= 1');
      addTearDown(controller.dispose);
      controller.setCursor(0);
      controller.popupController.show(['int']);

      controller.insertSelectedWord();

      expect(controller.popupController.shouldShow, isFalse);
      expect(controller.text, '= 1');
    });

    test('replaces the word at the cursor with the completion', () async {
      final controller = _makeController('int a;');
      addTearDown(controller.dispose);
      controller.setCursor(3);
      controller.popupController.show(['int']);

      controller.insertSelectedWord();

      expect(controller.text, 'int a;');
      expect(controller.popupController.shouldShow, isFalse);
    });

    test('keeps the finalizer spacing when the word is at a symbol', () async {
      final controller = _makeController('int;');
      addTearDown(controller.dispose);
      controller.setCursor(3);
      controller.popupController.show(['int']);

      controller.insertSelectedWord();

      expect(controller.text, 'int;');
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
    });

    test('adds a trailing space at the end of the text', () async {
      final controller = _makeController('int');
      addTearDown(controller.dispose);
      controller.setCursor(3);
      controller.popupController.show(['int']);

      controller.insertSelectedWord();

      expect(controller.text, 'int ');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });
  });

  group('CodeController.onEnterKeyAction', () {
    test('inserts the selected completion instead of a newline when '
        'the popup is open', () async {
      final controller = _makeController('pub');
      addTearDown(controller.dispose);
      controller.setCursor(3);

      await controller.generateSuggestions();
      expect(controller.popupController.shouldShow, isTrue);

      controller.onEnterKeyAction();

      expect(controller.text, 'public ');
      expect(controller.popupController.shouldShow, isFalse);
    });
  });

  group('CodeController.onTabKeyAction', () {
    test('inserts the tab width in spaces', () async {
      final controller = _makeController('a');
      addTearDown(controller.dispose);
      controller.setCursor(0);

      controller.onTabKeyAction();

      expect(controller.text, '  a');
    });

    test('inserts the selected completion instead of spaces when '
        'the popup is open', () async {
      final controller = _makeController('pub');
      addTearDown(controller.dispose);
      controller.setCursor(3);

      await controller.generateSuggestions();
      expect(controller.popupController.shouldShow, isTrue);

      controller.onTabKeyAction();

      expect(controller.text, 'public ');
      expect(controller.popupController.shouldShow, isFalse);
    });
  });

  group('CodeController.fullText', () {
    test('reads back the whole code', () {
      final controller = _makeController('int a;\nint b;');
      addTearDown(controller.dispose);

      expect(controller.fullText, 'int a;\nint b;');
    });

    test('replaces the whole code', () {
      final controller = _makeController('int a;');
      addTearDown(controller.dispose);

      controller.fullText = 'void main() {}';

      expect(controller.text, 'void main() {}');
      expect(controller.fullText, 'void main() {}');
    });

    test('turns tabs into spaces when a TabModifier is active', () {
      final controller = _makeController(''); // default modifiers
      addTearDown(controller.dispose);

      controller.fullText = '\tint a;';

      expect(controller.text, '  int a;');
    });
  });

  group('CodeController.dismiss', () {
    test('hides the autocomplete popup through the public dismiss', () {
      final controller = _makeController('');
      addTearDown(controller.dispose);
      controller.popupController.show(['int']);

      controller.dismiss();

      expect(controller.popupController.shouldShow, isFalse);
    });
  });
}
