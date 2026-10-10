import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

void main() {
  group('CodeSearchController focus', () {
    testWidgets('Escape inside the pattern field hides the search', (wt) async {
      final controller = await pumpController(wt, 'Aa');

      controller.showSearch();
      await wt.pumpAndSettle();
      expect(controller.searchController.shouldShow, true);

      controller.searchController.patternFocusNode.requestFocus();
      await wt.pump();

      await wt.sendKeyEvent(LogicalKeyboardKey.escape);
      await wt.pumpAndSettle();

      expect(controller.searchController.shouldShow, false);
    });

    testWidgets('codeFieldFocusNode is mirrored and can be nulled', (wt) async {
      final controller = await pumpController(wt, 'Aa');

      final search = controller.searchController;
      // `CodeField.initState` assigns the editor focus node.
      expect(search.codeFieldFocusNode, isNotNull);

      search.codeFieldFocusNode = null;
      expect(search.codeFieldFocusNode, isNull);
    });

    testWidgets('the hiding timer dismisses a defocused search', (wt) async {
      final controller = await pumpController(wt, 'Aa');
      final search = controller.searchController;

      search.showSearch();
      await wt.pumpAndSettle();

      // Neither the pattern field nor the code field holds focus, so the
      // periodic hiding check dismisses the search. The first tick after
      // showing resets the counter (the focus request in `showSearch`), so
      // the second one does the dismissing.
      search.patternFocusNode.unfocus();
      await wt.pump(const Duration(milliseconds: 1100));
      await wt.pump();
      await wt.pump(const Duration(milliseconds: 1100));
      await wt.pumpAndSettle();

      expect(search.shouldShow, false);
    });

    testWidgets('the hiding timer holds while focus churns', (wt) async {
      final controller = await pumpController(wt, 'Aa');
      final search = controller.searchController;

      search.showSearch();
      await wt.pumpAndSettle();

      // A focus event in the tick makes the timer reset its counter instead of
      // hiding the search — that is the search-navigation escape hatch.
      search.patternFocusNode.requestFocus();
      await wt.pump();
      search.patternFocusNode.unfocus();
      await wt.pump(const Duration(milliseconds: 1100));
      await wt.pumpAndSettle();

      expect(search.shouldShow, true);
    });
  });
}
