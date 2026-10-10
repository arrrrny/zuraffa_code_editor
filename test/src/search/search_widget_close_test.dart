import 'package:zuraffa_code_editor/src/search/widget/search_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// The close icon in the search bar dismisses the panel and hands focus back to
/// the editor, the same way `controller.dismiss()` does.
void main() {
  testWidgets('tapping the close icon dismisses the search panel', (wt) async {
    final controller = await pumpController(wt, 'Aaa');
    await wt.pumpAndSettle();

    controller.showSearch();
    await wt.pumpAndSettle();

    expect(controller.searchController.shouldShow, isTrue);
    expect(find.byType(SearchWidget), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await wt.tap(find.byIcon(Icons.close));
    await wt.pumpAndSettle();

    expect(controller.searchController.shouldShow, isFalse);
    expect(find.byType(SearchWidget), findsNothing);
  });
}
