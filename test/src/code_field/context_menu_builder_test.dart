// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// #12 — `CodeField` did not expose `contextMenuBuilder`.
///
/// Flutter's `TextField` and `EditableText` let the app replace the selection
/// toolbar; a code editor is where that matters most, because the actions an
/// app wants next to a selection (search, format, go to line) are its own, not
/// Flutter's. `CodeField` built its `TextField` without forwarding the
/// parameter, so the default platform toolbar was the only option.
///
/// The gesture this file drives is a long press on the first line of text, which
/// is the only way a touch selection appears in a widget test; the editor's own
/// keyboard shortcuts are wired elsewhere and are unaffected.
void main() {
  Widget app({
    required CodeController controller,
    EditableTextContextMenuBuilder? contextMenuBuilder,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CodeField(
          controller: controller,
          contextMenuBuilder: contextMenuBuilder,
        ),
      ),
    );
  }

  /// Long presses on the first line of code, so the editor has a selection the
  /// menu can be offered for.
  Future<void> longPressOnFirstLine(WidgetTester wt) async {
    await wt.pumpAndSettle();
    final editable = wt.getRect(find.byType(EditableText));
    await wt.longPressAt(editable.topLeft + const Offset(20, 10));
    await wt.pumpAndSettle();
  }

  group('CodeField context menu (#12)', () {
    testWidgets("the issue's proposed API replaces the toolbar", (wt) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      await wt.pumpWidget(
        app(
          controller: controller,
          contextMenuBuilder: (context, editableTextState) {
            return AdaptiveTextSelectionToolbar(
              anchors: editableTextState.contextMenuAnchors,
              children: const [Text('EDITOR_MENU')],
            );
          },
        ),
      );
      await longPressOnFirstLine(wt);

      expect(find.text('EDITOR_MENU'), findsOneWidget);
    });

    testWidgets('the builder sees the editor state, not a stand-in', (
      wt,
    ) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      EditableTextState? handedToBuilder;

      await wt.pumpWidget(
        app(
          controller: controller,
          contextMenuBuilder: (context, editableTextState) {
            handedToBuilder = editableTextState;
            return const SizedBox.shrink();
          },
        ),
      );
      await longPressOnFirstLine(wt);

      expect(
        handedToBuilder,
        isNotNull,
        reason: 'the forwarded builder must be consulted on a selection',
      );
      expect(handedToBuilder!.textEditingValue.text, controller.text);
      expect(handedToBuilder!.textEditingValue.selection, controller.selection);
    });

    testWidgets('the platform menu survives when no builder is given', (
      wt,
    ) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      await wt.pumpWidget(app(controller: controller));
      await longPressOnFirstLine(wt);

      expect(
        find.byType(AdaptiveTextSelectionToolbar),
        findsOneWidget,
        reason:
            "CodeField must not swallow TextField's own default menu: an "
            'explicit null contextMenuBuilder turns the toolbar off outright',
      );
      expect(
        find.byType(TextSelectionToolbarTextButton),
        findsWidgets,
        reason: 'the default menu still carries Copy / Select All',
      );
    });

    testWidgets('an empty builder suppresses the menu', (wt) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      await wt.pumpWidget(
        app(
          controller: controller,
          contextMenuBuilder: (context, editableTextState) =>
              const SizedBox.shrink(),
        ),
      );
      await longPressOnFirstLine(wt);

      expect(
        find.byType(AdaptiveTextSelectionToolbar),
        findsNothing,
        reason: 'a builder that renders nothing must leave no menu behind',
      );
      expect(controller.selection.isCollapsed, isFalse);
    });
  });
}
