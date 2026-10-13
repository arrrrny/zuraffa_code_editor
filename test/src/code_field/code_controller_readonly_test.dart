/// How typing is driven here, measured rather than assumed.
///
/// A newline is sent as a real key event — `LogicalKeyboardKey.enter` reaches
/// `EnterKeyAction` → `CodeController.onEnterKeyAction` → `insertStr('\n')`,
/// which writes through `text` and so lands in `set value` →
/// `_getEditResultNotBreakingReadOnly`: the same read-only gate a direct value
/// write hits. Both the accepted and the refused newline cases below are
/// therefore genuine key-event coverage of that gate.
///
/// A printable character cannot be, and that is not an oversight:
///
/// ```dart
/// final res = await wt.sendKeyEvent(LogicalKeyboardKey.keyX);
/// // res == false, and controller.text does not move
/// ```
///
/// `sendKeyEvent` returns `false` because `CodeController.onKey` answers
/// `KeyEventResult.ignored` for printable keys — the framework's `EditableText`
/// leaves them to the platform IME, which a widget test does not have. Writing
/// `controller.value` is the established way this package drives a character
/// (`insert_overtype_test.dart` does the same through its `_typedAt` helper).
///
/// Splitting a character-plus-newline write into the two keystrokes it stands
/// for is deliberately NOT done: a typed character opens the autocomplete popup
/// (this file loads the `java` language), and `onEnterKeyAction` then accepts
/// the selected word instead of inserting a newline. Verified: replacing
/// `replacedSelection('a')` + `enter` in the "Junction of and read-only and
/// editable" test below inserts `abstract`, not a line break. So the atomic
/// write, which bypasses the popup the way the original upstream test did, is
/// the faithful stand-in for that keystroke pair.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import '../common/create_app.dart';
import '../common/text_editing_value.dart';

const _editableBeginningEnd = '''
abc
ro//readonly
ro//readonly
abc
''';

const _editableBetween = '''
ro//readonly
abc
ro//readonly
''';

final _language = java;

void main() {
  group('CodeController Read-only', () {
    testWidgets('Can edit at editable beginning of the document', (
      WidgetTester wt,
    ) async {
      final controller = CodeController(
        text: _editableBeginningEnd,
        language: _language,
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      // Go to the beginning.
      await wt.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.alt);

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\nabc\n',
          //     \ cursor
          selection: TextSelection.collapsed(offset: 0),
        ),
        reason: 'Backspace - No effect',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nabc\n',
        reason: 'Backspace - No effect',
      );

      await wt.sendKeyEvent(LogicalKeyboardKey.delete);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'bc\nro\nro\nabc\n',
          //     \ cursor
          selection: TextSelection.collapsed(offset: 0),
        ),
        reason: 'Delete - OK',
      );
      expect(
        controller.fullText,
        'bc\nro//readonly\nro//readonly\nabc\n',
        reason: 'Delete - OK',
      );

      // A character is a value write; see the header for why a key event
      // cannot do it.
      controller.value = controller.value.replacedSelection('a\n');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'a\nbc\nro\nro\nabc\n',
          //        \ cursor
          selection: TextSelection.collapsed(offset: 2),
        ),
        reason: 'Type - OK',
      );
      expect(
        controller.fullText,
        'a\nbc\nro//readonly\nro//readonly\nabc\n',
        reason: 'Type - OK',
      );
    });

    testWidgets('Can edit at editable end of the document', (
      WidgetTester wt,
    ) async {
      final controller = CodeController(
        text: _editableBeginningEnd,
        language: _language,
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      // Go to the beginning.
      await wt.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.alt);

      await wt.sendKeyEvent(LogicalKeyboardKey.delete);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\nabc\n',
          //               cursor /
          selection: TextSelection.collapsed(offset: 14),
        ),
        reason: 'Delete - no effect',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nabc\n',
        reason: 'Delete - no effect',
      );

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\nabc',
          //             cursor /
          selection: TextSelection.collapsed(offset: 13),
        ),
        reason: 'Backspace - OK',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nabc',
        reason: 'Backspace - OK',
      );

      // A character is a value write; see the header for why a key event
      // cannot do it.
      controller.value = controller.value.replacedSelection('d\n');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\nabcd\n',
          //                cursor /
          selection: TextSelection.collapsed(offset: 15),
        ),
        reason: 'Type - OK',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nabcd\n',
        reason: 'Type - OK',
      );
    });

    testWidgets('Junction of editable and read-only', (WidgetTester wt) async {
      final controller = CodeController(
        text: _editableBeginningEnd,
        language: _language,
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      // Go to the end of the editable line before a read-only line.
      await wt.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.alt);

      await wt.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      await wt.sendKeyEvent(LogicalKeyboardKey.delete);

      // TODO(yescorp): uncomment when flutter issue will be closed.
      //  https://github.com/akvelon/flutter-code-editor/issues/179
      // expect(
      //   controller.value,
      //   const TextEditingValue(
      //     text: 'abc\nro\nro\nabc\n',
      //     //        \ cursor
      //     selection: TextSelection.collapsed(offset: 3),
      //   ),
      //   reason: 'Delete EOL before readonly - No effect',
      // );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nabc\n',
        reason: 'Delete EOL before readonly - No effect',
      );

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'ab\nro\nro\nabc\n',
          //       \ cursor
          selection: TextSelection.collapsed(offset: 2),
        ),
        reason: 'Backspace before EOL before readonly - OK',
      );
      expect(
        controller.fullText,
        'ab\nro//readonly\nro//readonly\nabc\n',
        reason: 'Backspace before EOL before readonly - OK',
      );

      // A character is a value write; see the header for why a key event
      // cannot do it.
      controller.value = controller.value.replacedSelection('c\n');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\n\nro\nro\nabc\n',
          //          \ cursor
          selection: TextSelection.collapsed(offset: 4),
        ),
        reason: 'Type before EOL before readonly - OK',
      );
      expect(
        controller.fullText,
        'abc\n\nro//readonly\nro//readonly\nabc\n',
        reason: 'Type before EOL before readonly - OK',
      );

      await wt.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      await wt.sendKeyEvent(LogicalKeyboardKey.delete);
      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);

      // A character is a value write; see the header for why a key event
      // cannot do it.
      controller.value = controller.value.replacedSelection('y');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\nabc\n',
          //          \ cursor
          selection: TextSelection.collapsed(offset: 4),
        ),
        reason: 'Del/Type at start of readonly - No effect, Backspace - OK',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nabc\n',
        reason: 'Del/Type at start of readonly - No effect, Backspace - OK',
      );

      // Still at the start of the read-only line: a real Enter key event must
      // not split it. The caret is not pinned — a refused Enter still advances
      // it one offset (issue #147).
      await wt.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(
        controller.value.text,
        'abc\nro\nro\nabc\n',
        reason: 'Newline at start of readonly - No effect',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nabc\n',
        reason: 'Newline at start of readonly - No effect',
      );
    });

    testWidgets('Junction of and read-only and editable', (
      WidgetTester wt,
    ) async {
      final controller = CodeController(
        text: _editableBeginningEnd,
        language: _language,
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      // Go to the beginning of the editable line after a read-only line.
      await wt.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.alt);

      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      await wt.sendKeyEvent(LogicalKeyboardKey.delete);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\nbc\n',
          //          cursor /
          selection: TextSelection.collapsed(offset: 10),
        ),
        reason: 'Delete at beginning of first editable line - OK',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nbc\n',
        reason: 'Delete at beginning of first editable line - OK',
      );

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\nbc\n',
          //          cursor /
          selection: TextSelection.collapsed(offset: 10),
        ),
        reason: 'Backspace at beginning of first editable line - No effect',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\nbc\n',
        reason: 'Backspace at beginning of first editable line - No effect',
      );

      // A character is a value write; see the header for why a key event
      // cannot do it.
      controller.value = controller.value.replacedSelection('a');
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      // Character plus newline, so kept as one atomic write: the `a` above
      // opened the autocomplete popup, `arrowLeft` does not close it, and a
      // real Enter would therefore accept `abstract` instead of breaking the
      // line. See the header.
      controller.value = controller.value.replacedSelection('\n');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\n\nabc\n',
          //            cursor /
          selection: TextSelection.collapsed(offset: 11),
        ),
        reason: 'Type at start of first editable line - OK',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\n\nabc\n',
        reason: 'Type at start of first editable line - OK',
      );

      // To the end of the last readonly line.
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      await wt.sendKeyEvent(LogicalKeyboardKey.delete);
      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      controller.value = controller.value.replacedSelection('a');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'abc\nro\nro\n\nabc\n',
          //        cursor /
          selection: TextSelection.collapsed(offset: 9),
        ),
        reason: 'Delete, Backspace, Type at last RO EOL - No effect',
      );
      expect(
        controller.fullText,
        'abc\nro//readonly\nro//readonly\n\nabc\n',
        reason: 'Delete, Backspace, Type at last RO EOL - No effect',
      );
    });

    testWidgets('Read-only beginning of the document', (WidgetTester wt) async {
      final controller = CodeController(
        text: _editableBetween,
        language: _language,
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      // Go to the beginning.
      await wt.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.alt);

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      await wt.sendKeyEvent(LogicalKeyboardKey.delete);

      // The whole document starts read-only, so neither the character write nor
      // a real Enter key event may take. The caret is not pinned — a refused
      // Enter still advances it one offset (issue #147).
      controller.value = controller.value.replacedSelection('a');
      await wt.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(
        controller.value.text,
        'ro\nabc\nro\n',
        reason: 'Backspace Delete Type - No effect',
      );
      expect(
        controller.fullText,
        'ro//readonly\nabc\nro//readonly\n',
        reason: 'Backspace Delete Type - No effect',
      );
    });

    testWidgets('Read-only end of the document', (WidgetTester wt) async {
      final controller = CodeController(
        text: _editableBetween,
        language: _language,
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      // Go to the end.
      await wt.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await wt.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.alt);

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      await wt.sendKeyEvent(LogicalKeyboardKey.delete);

      // A character is a value write; see the header for why a key event
      // cannot do it.
      controller.value = controller.value.replacedSelection('a\n');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'ro\nabc\nro\n',
          //          cursor /
          selection: TextSelection.collapsed(offset: 10),
        ),
        reason: 'Backspace Delete Type at last empty line - No effect',
      );
      expect(
        controller.fullText,
        'ro//readonly\nabc\nro//readonly\n',
        reason: 'Backspace Delete Type at last empty line - No effect',
      );

      await wt.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      await wt.sendKeyEvent(LogicalKeyboardKey.delete);

      // A character is a value write; see the header for why a key event
      // cannot do it.
      controller.value = controller.value.replacedSelection('a\n');

      expect(
        controller.value,
        const TextEditingValue(
          text: 'ro\nabc\nro\n',
          //        cursor /
          selection: TextSelection.collapsed(offset: 9),
        ),
        reason: 'Backspace Delete Type before last empty line - No effect',
      );
      expect(
        controller.fullText,
        'ro//readonly\nabc\nro//readonly\n',
        reason: 'Backspace Delete Type before last empty line - No effect',
      );
    });
  });
}
