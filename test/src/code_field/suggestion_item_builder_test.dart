import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// The wiring half of `CodeField.suggestionItemBuilder`, which the direct
/// `Popup` tests in `popup_item_builder_test.dart` cannot reach: the field has
/// to hand the builder to the popup it builds for its overlay. Mirrors
/// `autocomplete_popup_background_test.dart`, which pins the sibling parameter
/// the same way.
Future<CodeController> _pumpFieldWithPopup(
  WidgetTester tester, {
  Widget Function(BuildContext, String, bool, VoidCallback)? itemBuilder,
}) async {
  final controller = createController('int a;');
  addTearDown(controller.dispose);
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CodeField(
          controller: controller,
          focusNode: focusNode,
          suggestionItemBuilder: itemBuilder,
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
  group('CodeField suggestionItemBuilder', () {
    testWidgets('a builder set on the field reaches the popup rows', (
      tester,
    ) async {
      final seen = <String>[];
      await _pumpFieldWithPopup(
        tester,
        itemBuilder: (context, suggestion, isSelected, onSelect) {
          seen.add(suggestion);
          return Text('row $suggestion', textDirection: TextDirection.ltr);
        },
      );

      // The field handed the builder to the popup, which used it for both rows.
      expect(seen, ['abc', 'def']);
      expect(find.text('row abc'), findsOneWidget);
      expect(find.text('row def'), findsOneWidget);
      // The built-in row is out of the tree, so the field's popup is the host's.
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('no builder renders the built-in row through the field', (
      tester,
    ) async {
      await _pumpFieldWithPopup(tester);

      expect(find.byType(Popup), findsOneWidget);
      expect(find.byType(InkWell), findsNWidgets(2));
    });
  });
}
