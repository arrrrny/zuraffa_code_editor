import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/code_field/default_styles.dart';
import 'package:zuraffa_code_editor/src/search/widget/search_widget.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// The root `Container` `CodeField.build` returns inside its
/// [FocusableActionDetector]. Both the theme-derived background
/// (`_backgroundCol`) and `widget.decoration` land on it, so it is the only
/// place the two can be told apart.
Container _rootContainer(WidgetTester tester) {
  return tester.widget<Container>(
    find
        .descendant(
          of: find.byType(CodeField),
          matching: find.byType(Container),
        )
        .first,
  );
}

Future<CodeController> _pumpField(
  WidgetTester tester, {
  Decoration? decoration,
  Color? background,
  CodeThemeData? codeTheme,
  ThemeData? theme,
}) async {
  final controller = createController('int a;');
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
            background: background,
          ),
        ),
      ),
    ),
  );

  return controller;
}

/// `ThemeData.light()` with an empty `TextTheme`: every one of the fourteen
/// slots `_getTextColorFromTheme` walks is nulled, so the `??` chain runs to
/// its end and the function falls back to `colorScheme.onSurface`.
ThemeData emptyTextTheme() {
  return ThemeData.light().copyWith(textTheme: const TextTheme());
}

void main() {
  group('CodeField background resolution', () {
    testWidgets('falls back to the default background without a theme', (
      tester,
    ) async {
      await _pumpField(tester);

      expect(_rootContainer(tester).color, DefaultStyles.backgroundColor);
    });

    testWidgets("uses the CodeTheme root style's background colour", (
      tester,
    ) async {
      const themeBackground = Color(0xff123456);

      await _pumpField(
        tester,
        codeTheme: CodeThemeData(
          styles: const {'root': TextStyle(backgroundColor: themeBackground)},
        ),
      );

      expect(_rootContainer(tester).color, themeBackground);
    });

    testWidgets('an explicit background beats the CodeTheme root style', (
      tester,
    ) async {
      const themeBackground = Color(0xff123456);
      const explicitBackground = Color(0xff654321);

      await _pumpField(
        tester,
        background: explicitBackground,
        codeTheme: CodeThemeData(
          styles: const {'root': TextStyle(backgroundColor: themeBackground)},
        ),
      );

      expect(_rootContainer(tester).color, explicitBackground);
    });

    testWidgets('a decoration drops the background colour', (tester) async {
      const decoration = BoxDecoration(color: Color(0xffabcdef));

      await _pumpField(tester, decoration: decoration);

      final root = _rootContainer(tester);
      expect(root.color, isNull);
      expect(root.decoration, same(decoration));
    });
  });

  group('CodeField search overlay', () {
    testWidgets("takes the border colour from the text theme's bodyLarge", (
      tester,
    ) async {
      final theme = emptyTextTheme().copyWith(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(onSurface: Colors.purple),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xff112233)),
        ),
      );

      final controller = await _pumpField(tester, theme: theme);

      controller.showSearch();
      await tester.pumpAndSettle();

      final overlayBorder =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.byType(SearchWidget),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      controller.dismiss();
      await tester.pumpAndSettle();
      controller.dispose();

      expect(overlayBorder.border?.top.color, const Color(0xff112233));
    });

    testWidgets('falls through every text-theme slot to onSurface', (
      tester,
    ) async {
      final theme = emptyTextTheme().copyWith(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(onSurface: Colors.purple),
      );

      final controller = await _pumpField(tester, theme: theme);

      controller.showSearch();
      await tester.pumpAndSettle();

      final overlayBorder =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.byType(SearchWidget),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      controller.dismiss();
      await tester.pumpAndSettle();
      controller.dispose();

      expect(overlayBorder.border?.top.color, Colors.purple);
    });
  });
}
