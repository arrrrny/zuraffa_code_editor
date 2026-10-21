library;

import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// #92 — `CodeField` had no way to hear a tap inside the editor.
///
/// Wrapping the editor in a `GestureDetector` does not work and never will: the
/// tap is a contest for the gesture arena, and the recognizers `TextField`
/// installs for its own text selection are *children* of the field, so they win
/// it. A parent detector then sees nothing — no error, no callback. Upstream
/// akvelon/flutter-code-editor#236 is a host hitting exactly that wall.
///
/// `TextField` has always had an `onTap` for this; `CodeField` simply never
/// forwarded it, because the editor built its field by enumerating the
/// parameters it needed rather than the ones it accepted. Forwarding it is the
/// whole fix: the field's own recognizers stay where they are, so where a tap
/// puts the caret and how a drag makes a selection do not change at all.
void main() {
  Widget app({required CodeController controller, VoidCallback? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: CodeField(
          renderer: CodeFieldRenderer.textField,
          controller: controller,
          onTap: onTap,
        ),
      ),
    );
  }

  /// Taps the middle of the first line of text, which is both the gesture a
  /// touch user makes and the placement an existing caret-placement test
  /// covers.
  Future<void> tapInField(WidgetTester wt) async {
    await wt.pumpAndSettle();
    final rect = wt.getRect(find.byType(EditableText));
    await wt.tapAt(rect.center);
    await wt.pumpAndSettle();
  }

  group('CodeField onTap (#92)', () {
    testWidgets('a tap inside the field reaches the callback', (wt) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      var taps = 0;

      await wt.pumpWidget(app(controller: controller, onTap: () => taps++));
      await tapInField(wt);

      expect(taps, 1);
    });

    testWidgets('every tap reaches the callback, not just the first', (
      wt,
    ) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      var taps = 0;

      await wt.pumpWidget(app(controller: controller, onTap: () => taps++));
      await tapInField(wt);
      await tapInField(wt);

      expect(taps, 2);
    });

    testWidgets('the tap still focuses the field', (wt) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      final focusNode = FocusNode();

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              renderer: CodeFieldRenderer.textField,
              controller: controller,
              focusNode: focusNode,
              onTap: () {},
            ),
          ),
        ),
      );
      await tapInField(wt);

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('the tap still places the caret', (wt) async {
      final controller = createController('int a = 1;\nint b = 2;\n');
      var taps = 0;

      await wt.pumpWidget(app(controller: controller, onTap: () => taps++));
      final rect = wt.getRect(find.byType(EditableText));
      await wt.pumpAndSettle();
      await wt.tapAt(rect.centerLeft + const Offset(10, 0));
      await wt.pumpAndSettle();

      // The field's own recognizer keeps its job: the tap still places a
      // collapsed caret inside the document rather than merely notifying the
      // host, so the field is not left without a selection.
      expect(taps, 1);
      expect(controller.selection.isValid, isTrue);
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, greaterThanOrEqualTo(0));
    });

    testWidgets('a field with no callback still accepts the tap', (wt) async {
      final controller = createController('int a = 1;\nint b = 2;\n');

      await wt.pumpWidget(app(controller: controller));
      await tapInField(wt);

      expect(find.byType(EditableText), findsOneWidget);
    });
  });
}
