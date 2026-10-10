import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/comment_uncomment.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/copy.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/dismiss.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/enter_key.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/indent.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/outdent.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/redo.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/search.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/tab.dart';
import 'package:zuraffa_code_editor/src/code_field/actions/undo.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// #29 — "Handle Tab through Flutter shortcuts/actions".
///
/// The issue reports that Tab is processed by a raw key handler and asks for it
/// to move to Flutter's [Shortcuts]/[Actions] machinery. On this fork it already
/// is: `CodeField` builds a `FocusableActionDetector` whose `shortcuts` map sends
/// Tab to `TabKeyIntent`, Shift+Tab to `OutdentIntent`, and Enter to
/// `EnterKeyIntent`; `CodeController.actions` maps those intents to their
/// actions.
///
/// The thing worth pinning is the negative: `CodeController.onKey`, the raw key
/// path the issue wanted to move away from, owns **no** Tab or Enter branch. It
/// returns `ignored` for both, which is what hands them to the framework's
/// shortcut table instead of settling them locally. Without that assertion a
/// regression back to a raw handler would pass every behavioural test, because
/// the observable effect of a Tab would be identical either way.
KeyDownEvent _key(
  LogicalKeyboardKey logical, {
  PhysicalKeyboardKey? physical,
}) => KeyDownEvent(
  physicalKey: physical ?? logical.physicalKeyForTest,
  logicalKey: logical,
  timeStamp: Duration.zero,
);

/// `onKey` reads the physical key only for the Ctrl+F shortcut, and the logical
/// key for everything else, so a helper that derives one from the other keeps
/// the intent of every call site readable.
extension on LogicalKeyboardKey {
  PhysicalKeyboardKey get physicalKeyForTest => switch (this) {
    LogicalKeyboardKey.tab => PhysicalKeyboardKey.tab,
    LogicalKeyboardKey.enter => PhysicalKeyboardKey.enter,
    LogicalKeyboardKey.arrowUp => PhysicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown => PhysicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.keyF => PhysicalKeyboardKey.keyF,
    _ => throw UnimplementedError('map the physical key for $this'),
  };
}

void main() {
  group('#29 — Tab and Enter are not settled by the raw key path', () {
    CodeController controllerFor({String text = 'void main() {}'}) {
      final controller = CodeController(text: text);
      addTearDown(controller.dispose);
      return controller;
    }

    test('Tab is ignored, so the framework shortcut table dispatches it', () {
      expect(
        controllerFor().onKey(_key(LogicalKeyboardKey.tab)),
        KeyEventResult.ignored,
      );
    });

    testWidgets('Shift+Tab is ignored too, modifiers and all', (wt) async {
      final controller = controllerFor();

      // The raw path does not inspect modifiers at all: Shift+Tab reaches it as
      // the same logical Tab key, and it still declines to own it.
      await wt.sendKeyDownEvent(LogicalKeyboardKey.shift);
      final result = controller.onKey(_key(LogicalKeyboardKey.tab));
      await wt.sendKeyUpEvent(LogicalKeyboardKey.shift);

      expect(result, KeyEventResult.ignored);
    });

    test('Enter is ignored', () {
      expect(
        controllerFor().onKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.ignored,
      );
    });

    test('an upward or downward arrow outside the popup is ignored', () {
      final controller = controllerFor();

      expect(
        controller.onKey(_key(LogicalKeyboardKey.arrowUp)),
        KeyEventResult.ignored,
      );
      expect(
        controller.onKey(_key(LogicalKeyboardKey.arrowDown)),
        KeyEventResult.ignored,
      );
    });

    testWidgets('while composing, every key is ignored — Ctrl+F included', (
      wt,
    ) async {
      // Composition is owned by the platform; while it is in progress the raw
      // path declines every key, including Ctrl+F, so it cannot corrupt the
      // composing text.
      final controller = await pumpController(wt, 'void main()');

      controller.value = const TextEditingValue(
        text: 'void main()',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 4, end: 5),
      );

      expect(
        controller.onKey(_key(LogicalKeyboardKey.tab)),
        KeyEventResult.ignored,
      );
      expect(
        controller.onKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.ignored,
      );

      await wt.sendKeyDownEvent(LogicalKeyboardKey.control);
      final result = controller.onKey(_key(LogicalKeyboardKey.keyF));
      await wt.sendKeyUpEvent(LogicalKeyboardKey.control);

      expect(result, KeyEventResult.ignored);
      expect(controller.searchController.shouldShow, isFalse);
    });
  });

  group('#29 — Ctrl+F is the one shortcut the raw path owns', () {
    testWidgets('and it opens the search', (wt) async {
      final controller = await pumpController(wt, 'void main() {}');

      await wt.sendKeyDownEvent(LogicalKeyboardKey.control);
      final result = controller.onKey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyF,
          logicalKey: LogicalKeyboardKey.keyF,
          timeStamp: Duration.zero,
        ),
      );
      await wt.sendKeyUpEvent(LogicalKeyboardKey.control);

      expect(result, KeyEventResult.handled);
      expect(
        controller.searchController.shouldShow,
        isTrue,
        reason:
            'pinning the boundary: onKey is not empty, it just does not own '
            'the character-shaped keys the shortcut table claims',
      );
    });
  });

  group('#29 — the intents the shortcut table dispatches have actions', () {
    test('every intent CodeController declares is answered by an action', () {
      final controller = CodeController();
      addTearDown(controller.dispose);

      final actions = controller.actions;

      expect(actions[IndentIntent], isA<IndentIntentAction>());
      expect(actions[OutdentIntent], isA<OutdentIntentAction>());
      expect(actions[TabKeyIntent], isA<TabKeyAction>());
      expect(actions[EnterKeyIntent], isA<EnterKeyAction>());
      expect(actions[CommentUncommentIntent], isA<CommentUncommentAction>());
      expect(actions[SearchIntent], isA<SearchAction>());
      expect(actions[DismissIntent], isA<CustomDismissAction>());
      expect(actions[CopySelectionTextIntent], isA<CopyAction>());
      expect(actions[UndoTextIntent], isA<UndoAction>());
      expect(actions[RedoTextIntent], isA<RedoAction>());
    });

    test('the actions share the controller that dispatches them', () {
      final controller = CodeController();
      addTearDown(controller.dispose);

      expect(
        (controller.actions[TabKeyIntent] as TabKeyAction).controller,
        same(controller),
      );
      expect(
        (controller.actions[EnterKeyIntent] as EnterKeyAction).controller,
        same(controller),
      );
      expect(
        (controller.actions[OutdentIntent] as OutdentIntentAction).controller,
        same(controller),
      );
    });
  });

  group('#29 — the shortcut table still delivers the edit', () {
    testWidgets('a real Tab inserts the editor indent', (wt) async {
      final controller = await pumpController(wt, 'void main() {}');

      controller.selection = const TextSelection.collapsed(offset: 14);
      await wt.pumpAndSettle();

      await wt.sendKeyEvent(LogicalKeyboardKey.tab);
      await wt.pumpAndSettle();

      expect(
        controller.text,
        'void main() {}${' ' * controller.params.tabSpaces}',
      );
      expect(controller.selection.baseOffset, 14 + controller.params.tabSpaces);
    });

    testWidgets('a real Shift+Tab outdents the caret line', (wt) async {
      // Outdent removes one indent level, so the line starts out already
      // indented and ends up at column zero.
      const indented = '  hello';
      final controller = await pumpController(wt, indented);

      controller.selection = const TextSelection.collapsed(offset: 7);
      await wt.pumpAndSettle();

      await wt.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await wt.sendKeyEvent(LogicalKeyboardKey.tab);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await wt.pumpAndSettle();

      expect(controller.text, 'hello');
    });

    testWidgets('a real Enter breaks the line through the action, not the raw '
        'path', (wt) async {
      final controller = await pumpController(wt, 'void main() {}');

      controller.selection = const TextSelection.collapsed(offset: 4);
      await wt.pumpAndSettle();

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pumpAndSettle();

      expect(controller.text, 'void\n main() {}');
    });
  });
}
