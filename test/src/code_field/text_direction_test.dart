import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// #14 — "Support for Arabic Language and RTL Directionality".
///
/// The issue asks for two things: the editor should *detect* an RTL context (a
/// system locale that is Arabic) and it should *allow setting* the direction
/// when it does not. Detection already worked — a [TextField] reads the ambient
/// [Directionality] — but nothing let a caller force it, and the direction the
/// field rendered in was invisible to everything the editor measured with:
/// every [TextPainter] it built hardcoded [TextDirection.ltr].
///
/// That last part was the defect. The painter that measures the caret feeds
/// `_getPopupLeftOffset`, so in an RTL field the autocomplete popup was placed
/// where the caret *would* be if the text ran left to right — the far side of
/// the editor. The offsets below pin which edge each caret actually lands on.
///
/// The row-height painters are direction-independent and are deliberately left
/// measuring as [TextDirection.ltr]: a paragraph's direction moves text
/// horizontally, never vertically, and the gutter's row heights are what those
/// painters exist for (see #18).
Future<CodeController> pumpEditorWithDirection(
  WidgetTester wt,
  String text, {
  TextDirection? textDirection,
  TextDirection ambient = TextDirection.ltr,
}) async {
  final controller = createController(text);
  final node = FocusNode();

  await wt.pumpWidget(
    MaterialApp(
      home: Directionality(
        // Inside `home`, not around the app: an `MaterialApp` installs its own
        // Directionality from its locale, which is exactly the path an Arabic
        // locale takes in a real app.
        textDirection: ambient,
        child: Scaffold(
          body: CodeField(
            controller: controller,
            focusNode: node,
            textDirection: textDirection,
          ),
        ),
      ),
    ),
  );
  node.requestFocus();
  await wt.pumpAndSettle();

  addTearDown(controller.dispose);
  addTearDown(node.dispose);

  return controller;
}

/// Puts the caret at [caret], opens the suggestion popup, and returns the
/// horizontal offset the field computed for it — the value that carries the
/// direction the caret was measured in.
Future<double> popupOffsetDx(
  WidgetTester wt,
  CodeController controller,
  int caret,
) async {
  controller.selection = TextSelection.collapsed(offset: caret);
  await wt.pumpAndSettle();

  controller.popupController.show(['alpha', 'beta']);
  await wt.pumpAndSettle();

  return wt.widget<Popup>(find.byType(Popup)).normalOffset.dx;
}

void main() {
  group('#14 — the field can be told its text direction', () {
    testWidgets('an explicit textDirection reaches the field', (wt) async {
      await pumpEditorWithDirection(
        wt,
        'void main() {}',
        textDirection: TextDirection.rtl,
      );

      expect(
        wt.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.rtl,
      );
    });

    testWidgets('an LTR locale leaves the field LTR', (wt) async {
      await pumpEditorWithDirection(wt, 'void main() {}');

      expect(
        wt.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('an ambient RTL locale is detected without a parameter', (
      wt,
    ) async {
      await pumpEditorWithDirection(
        wt,
        'void main() {}',
        ambient: TextDirection.rtl,
      );

      expect(
        wt.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.rtl,
        reason:
            'the field resolves the ambient Directionality, so an Arabic '
            'locale installs RTL with no configuration at all',
      );
    });

    testWidgets('an ambient RTL locale measures the caret as RTL', (wt) async {
      // The gutter flips to the right edge under an RTL locale, which moves the
      // editor box's own origin too — so what is pinned is the edge the caret
      // lands on, not an absolute offset.
      const text = 'void main() {}';

      final rtl = await pumpEditorWithDirection(
        wt,
        text,
        ambient: TextDirection.rtl,
      );
      final rtlEnd = await popupOffsetDx(wt, rtl, text.length);

      final ltr = await pumpEditorWithDirection(wt, text);
      final ltrEnd = await popupOffsetDx(wt, ltr, text.length);

      expect(
        rtlEnd,
        lessThan(40),
        reason: 'the end of the text is the left edge of the editor in RTL',
      );
      expect(
        ltrEnd,
        greaterThan(250),
        reason:
            'and the right edge in LTR — a hardcoded LTR painter puts both '
            'at the right edge',
      );
    });
  });

  group('#14 — the caret is measured in the direction the field renders', () {
    testWidgets('an RTL field measures the caret against the RTL layout', (
      wt,
    ) async {
      const text = 'void main() {}';

      final rtl = await pumpEditorWithDirection(
        wt,
        text,
        textDirection: TextDirection.rtl,
      );
      final rtlStart = await popupOffsetDx(wt, rtl, 0);
      final rtlEnd = await popupOffsetDx(wt, rtl, text.length);

      final ltr = await pumpEditorWithDirection(wt, text);
      final ltrStart = await popupOffsetDx(wt, ltr, 0);
      final ltrEnd = await popupOffsetDx(wt, ltr, text.length);

      expect(
        rtlStart,
        greaterThan(ltrStart),
        reason:
            'offset 0 is the left edge of the line box in LTR and inside '
            'the line in RTL, where the trailing space and the braces reorder '
            'around the Latin run',
      );
      expect(
        rtlEnd,
        lessThan(ltrEnd - 100),
        reason:
            'the end of the text is the left edge in RTL and the right '
            'edge in LTR — the whole point of measuring the caret in the '
            'direction the field renders. A hardcoded LTR painter gives the '
            'same offset for both',
      );
    });

    testWidgets('LTR behaviour is unchanged', (wt) async {
      const text = 'void main() {}';
      final ltr = await pumpEditorWithDirection(wt, text);

      final start = await popupOffsetDx(wt, ltr, 0);
      final middle = await popupOffsetDx(wt, ltr, 4);
      final end = await popupOffsetDx(wt, ltr, text.length);

      expect(middle, greaterThan(start + 60));
      expect(middle, lessThan(start + 100));
      expect(end, greaterThan(middle + 100));
      expect(
        start,
        greaterThan(40),
        reason:
            'the editor box starts to the right of the gutter, so the '
            'first caret is not at the window\'s left edge',
      );
    });
  });

  group('#14 — the gutter follows the text direction', () {
    testWidgets('an RTL locale moves the gutter to the right edge', (wt) async {
      await pumpEditorWithDirection(
        wt,
        'void main() {}',
        ambient: TextDirection.rtl,
      );
      final rtlGutter = wt.getTopLeft(find.byType(Table).first).dx;

      await pumpEditorWithDirection(wt, 'void main() {}');
      final ltrGutter = wt.getTopLeft(find.byType(Table).first).dx;

      expect(rtlGutter, greaterThan(400));
      expect(ltrGutter, lessThan(40));
    });

    testWidgets('forcing RTL on the field alone keeps the gutter on the left', (
      wt,
    ) async {
      // The parameter is about the text, not the app: it does not reach the
      // Row the gutter is laid out in, which still reads the ambient
      // Directionality. A locale-wide RTL install is what flips the gutter.
      await pumpEditorWithDirection(
        wt,
        'void main() {}',
        textDirection: TextDirection.rtl,
      );

      expect(wt.getTopLeft(find.byType(Table).first).dx, lessThan(40));
    });
  });
}
