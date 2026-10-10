import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/code_field/default_styles.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// The `Container` inside [Popup] that paints the background and the border.
/// Its `BoxDecoration.color` is the only place the popup's background is
/// expressed, so it is what a transparency report is about.
Color? _popupBackground(WidgetTester tester) {
  final decoration =
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(Popup),
                      matching: find.byType(Container),
                    )
                    .last,
              )
              .decoration
          as BoxDecoration;

  return decoration.color;
}

Future<CodeController> _pumpFieldWithPopup(
  WidgetTester tester, {
  Decoration? decoration,
  Color? autocompleteBackground,
  CodeThemeData? codeTheme,
  ThemeData? theme,
}) async {
  final controller = createController('int a;');
  addTearDown(controller.dispose);
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: CodeTheme(
          data: codeTheme,
          child: CodeField(
            controller: controller,
            focusNode: focusNode,
            decoration: decoration,
            autocompleteBackground: autocompleteBackground,
          ),
        ),
      ),
    ),
  );

  // `windowSize` is filled in a post-frame callback, and the popup is only
  // built once it is non-null.
  await tester.pump();

  controller.popupController.show(const ['abc', 'def']);
  await tester.pump();

  addTearDown(() {
    controller.popupController.hide();
  });

  return controller;
}

void main() {
  group('Autocomplete popup background', () {
    testWidgets('falls back to an opaque colour when a decoration is set', (
      tester,
    ) async {
      await _pumpFieldWithPopup(
        tester,
        decoration: const BoxDecoration(color: Color(0xffabcdef)),
      );

      expect(_popupBackground(tester), isNotNull);
      expect(_popupBackground(tester)!.a, 1.0);
    });

    testWidgets('an explicit autocompleteBackground wins over both', (
      tester,
    ) async {
      await _pumpFieldWithPopup(
        tester,
        decoration: const BoxDecoration(color: Color(0xffabcdef)),
        autocompleteBackground: const Color(0xff123456),
      );

      expect(_popupBackground(tester), const Color(0xff123456));
    });

    testWidgets('without a decoration the editor background is kept', (
      tester,
    ) async {
      await _pumpFieldWithPopup(tester);

      expect(_popupBackground(tester), DefaultStyles.backgroundColor);
    });
  });
}
