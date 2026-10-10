import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import '../common/create_app.dart';

/// #21 — outdent on Backspace.
///
/// The reporter wanted a `CodeModifier` registered on `'\b'` and found it can
/// never fire: `CodeController` dispatches from `value`'s setter, where the key
/// is the character that was *typed*, and `_insertedLoc` only reports a
/// single-character insertion. A backspace inserts nothing, so no key is ever
/// produced for it.
///
/// These tests pin both halves of the fix: the deletion dispatch itself (a
/// modifier registered with `deletesChar` is consulted, one registered only for
/// an inserted character is not), and the `OutdentModifier` that ships in
/// `defaultCodeModifiers`.

/// Deletes the character before [offset], the way the framework's
/// `EditableText` delivers a backspace through `value`'s setter.
TextEditingValue _backspaceAt(TextEditingValue value, int offset) {
  assert(offset > 0 && offset <= value.text.length);

  return TextEditingValue(
    text: value.text.replaceRange(offset - 1, offset, ''),
    selection: TextSelection.collapsed(offset: offset - 1),
  );
}

void main() {
  group('the deletion dispatch (#21)', () {
    test('consults a modifier registered for the deleted character', () {
      final seen = <String>[];
      final controller = CodeController(
        modifiers: [_RecordingModifier(' ', seen)],
      );
      controller.value = const TextEditingValue(
        text: '    return;',
        selection: TextSelection.collapsed(offset: 4),
      );

      controller.value = _backspaceAt(controller.value, 4);

      expect(seen, [
        '    return;',
      ], reason: 'the modifier sees the text as it was before the deletion');
    });

    test('lets the modifier rewrite the value, not just observe it', () {
      final controller = CodeController(
        modifiers: const [_DeletesTheIndentModifier()],
      );
      controller.value = const TextEditingValue(
        text: '    return;',
        selection: TextSelection.collapsed(offset: 4),
      );

      controller.value = _backspaceAt(controller.value, 4);

      expect(
        controller.value,
        const TextEditingValue(
          text: 'return;',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
    });

    test('reports the parameters an insertion modifier would see', () {
      var tabSpacesSeen = -1;

      final controller = CodeController(
        params: const EditorParams(tabSpaces: 3),
        modifiers: [
          _ParamsProbeModifier(
            ' ',
            (params) => tabSpacesSeen = params.tabSpaces,
          ),
        ],
      );
      controller.value = const TextEditingValue(
        text: '    return;',
        selection: TextSelection.collapsed(offset: 4),
      );

      controller.value = _backspaceAt(controller.value, 4);

      expect(tabSpacesSeen, 3);
    });

    test('does not consult a modifier registered only for insertions', () {
      var calls = 0;
      final controller = CodeController(
        modifiers: [_CountingModifier(' ', () => calls++)],
      );
      controller.value = const TextEditingValue(
        text: '    return;',
        selection: TextSelection.collapsed(offset: 4),
      );

      controller.value = _backspaceAt(controller.value, 4);

      expect(calls, 0, reason: 'existing insertion behaviour is untouched');
    });

    test('does not consult it when the text did not shrink by one', () {
      final seen = <String>[];
      final controller = CodeController(
        modifiers: [_RecordingModifier(' ', seen)],
      );
      controller.value = const TextEditingValue(
        text: '    return;',
        selection: TextSelection.collapsed(offset: 4),
      );

      // A selection delete removes four characters at once.
      controller.value = const TextEditingValue(
        text: 'return;',
        selection: TextSelection.collapsed(offset: 0),
      );

      expect(
        seen,
        isEmpty,
        reason: 'only a single-character delete dispatches',
      );
    });
  });

  group('OutdentModifier — the modifier the issue asked for (#21)', () {
    TextEditingValue backspaceIn(String text, int offset, {int tabSpaces = 4}) {
      final controller = CodeController(
        params: EditorParams(tabSpaces: tabSpaces),
      );
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
      );
      controller.value = _backspaceAt(controller.value, offset);
      return controller.value;
    }

    test('removes one indent level from the leading whitespace', () {
      expect(
        backspaceIn('        return;', 4),
        const TextEditingValue(
          text: '    return;',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
    });

    test('removes one indent level from the middle of the indent', () {
      expect(
        backspaceIn('        return;', 6),
        const TextEditingValue(
          text: '    return;',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
    });

    test('removes only the spaces that are there, not a full tab', () {
      expect(
        backspaceIn('  return;', 2),
        const TextEditingValue(
          text: 'return;',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
    });

    test('honours a tabSpaces other than four', () {
      expect(
        backspaceIn('      return;', 3, tabSpaces: 2),
        const TextEditingValue(
          text: '    return;',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
    });

    test('leaves a backspace in the code alone', () {
      expect(
        backspaceIn('    return;', 5),
        const TextEditingValue(
          text: '    eturn;',
          selection: TextSelection.collapsed(offset: 4),
        ),
        reason: 'a backspace outside the leading whitespace is not an outdent',
      );
    });

    test('is part of the default modifiers', () {
      expect(
        CodeController.defaultCodeModifiers.whereType<OutdentModifier>(),
        hasLength(1),
      );
    });

    test('does not fire for a disabled modifier set', () {
      final controller = CodeController(modifiers: const []);
      controller.value = const TextEditingValue(
        text: '        return;',
        selection: TextSelection.collapsed(offset: 4),
      );

      controller.value = _backspaceAt(controller.value, 4);

      expect(
        controller.value,
        const TextEditingValue(
          text: '       return;',
          selection: TextSelection.collapsed(offset: 3),
        ),
        reason: 'an opt-out keeps the plain one-space delete',
      );
    });
  });

  group('OutdentModifier and the read-only and folded paths (#21)', () {
    testWidgets('a read-only controller refuses the outdent', (wt) async {
      final controller = CodeController(
        text: '        return;',
        readOnly: true,
        params: const EditorParams(tabSpaces: 4),
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      controller.selection = const TextSelection.collapsed(offset: 4);
      await wt.pumpAndSettle();

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      await wt.pumpAndSettle();

      expect(
        controller.value,
        const TextEditingValue(
          text: '        return;',
          //    \ cursor
          selection: TextSelection.collapsed(offset: 4),
        ),
        reason: 'read-only means no edit at all',
      );
    });

    testWidgets('a real Backspace outdents below a folded block', (wt) async {
      const text = 'void main() {\n    first();\n}\n    return;\n';
      final controller = CodeController(
        text: text,
        language: java,
        params: const EditorParams(tabSpaces: 4),
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      // `void main() {` swallows `    first();`, so the caret's line sits
      // behind a hidden range.
      controller.foldAt(0);
      await wt.pumpAndSettle();
      expect(controller.code.hiddenRanges.ranges, isNotEmpty);

      // While a block is folded the field edits the visible text, so the
      // caret goes into the indent of `    return;` in visible coordinates:
      // `void main() {}\n` is 15 characters.
      controller.selection = const TextSelection.collapsed(offset: 19);
      await wt.pumpAndSettle();

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      await wt.pumpAndSettle();

      expect(
        controller.value,
        const TextEditingValue(
          text: 'void main() {}\nreturn;\n',
          //                \ cursor
          selection: TextSelection.collapsed(offset: 15),
        ),
        reason: 'the whole indent level goes, not one space',
      );
      expect(
        controller.fullText,
        'void main() {\n    first();\n}\nreturn;\n',
        reason: 'the outdent maps back into the full text, folded lines intact',
      );
      expect(
        controller.code.hiddenRanges.ranges,
        isNotEmpty,
        reason: 'the fold survives the edit',
      );
    });

    testWidgets('a real Backspace key outdents the editor', (wt) async {
      final controller = CodeController(
        text: '        return;',
        params: const EditorParams(tabSpaces: 4),
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      controller.selection = const TextSelection.collapsed(offset: 4);
      await wt.pumpAndSettle();

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      await wt.pumpAndSettle();

      expect(
        controller.value,
        const TextEditingValue(
          text: '    return;',
          //                \ cursor
          selection: TextSelection.collapsed(offset: 0),
        ),
        reason: 'the whole indent level goes, not one space',
      );
    });

    testWidgets('a real Backspace outside the indent deletes one char', (
      wt,
    ) async {
      final controller = CodeController(
        text: '        return;',
        params: const EditorParams(tabSpaces: 4),
      );
      final focusNode = FocusNode();

      await wt.pumpWidget(createApp(controller, focusNode));
      focusNode.requestFocus();

      controller.selection = const TextSelection.collapsed(offset: 9);
      await wt.pumpAndSettle();

      await wt.sendKeyEvent(LogicalKeyboardKey.backspace);
      await wt.pumpAndSettle();

      expect(
        controller.value,
        const TextEditingValue(
          text: '        eturn;',
          //                 \ cursor
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
    });
  });
}

/// A modifier registered for a *deletion*, which records the text it was shown.
class _RecordingModifier extends CodeModifier {
  final List<String> seen;

  _RecordingModifier(super.char, this.seen) : super(deletesChar: ' ');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    seen.add(text);
    return null;
  }
}

/// A deletion modifier that rewrites the value.
class _DeletesTheIndentModifier extends CodeModifier {
  const _DeletesTheIndentModifier() : super(' ', deletesChar: ' ');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) => const TextEditingValue(
    text: 'return;',
    selection: TextSelection.collapsed(offset: 0),
  );
}

/// A deletion modifier that only reports the parameters it was handed.
class _ParamsProbeModifier extends CodeModifier {
  final void Function(EditorParams) onParams;

  _ParamsProbeModifier(super.char, this.onParams) : super(deletesChar: ' ');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    onParams(params);
    return null;
  }
}

/// A modifier with no `deletesChar`, which must never be consulted for a
/// deletion.
class _CountingModifier extends CodeModifier {
  final void Function() onUpdate;

  const _CountingModifier(super.char, this.onUpdate) : super();

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    onUpdate();
    return null;
  }
}
