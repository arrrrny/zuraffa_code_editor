// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_final_locals

import 'package:flutter/rendering.dart';
import 'package:zuraffa_code_editor/src/code_field/code_controller.dart';
import 'package:zuraffa_code_editor/src/search/match.dart';
import 'package:zuraffa_code_editor/src/search/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// Types the pattern into the search overlay, the way the widget does.
void _searchFor(CodeController controller, String pattern) {
  controller.showSearch();
  controller.searchController.settingsController.patternController.text =
      pattern;
  controller.searchController.settingsController.value = SearchSettings(
    isCaseSensitive: true,
    isRegExp: false,
    pattern: pattern,
  );
}

void main() {
  group('CodeController.onEnterKeyAction', () {
    testWidgets(
      'repeats the search instead of inserting a newline when already on a match',
      (wt) async {
        const text = 'aaaAAAaaa';
        final controller = await pumpController(wt, text);

        _searchFor(controller, 'A');
        await wt.pump();

        // The navigation starts on the first match, (3, 4).
        controller.selection = const TextSelection(
          baseOffset: 3,
          extentOffset: 4,
        );
        controller.onEnterKeyAction();

        expect(controller.text, text);
        // `moveNext` wrapped around to the second match instead of inserting a
        // newline.
        expect(
          controller.selection,
          const TextSelection(baseOffset: 4, extentOffset: 5),
        );

        controller.dismiss();
        await wt.pumpAndSettle();
      },
    );

    testWidgets('inserts a newline when the selection is off every match', (
      wt,
    ) async {
      const text = 'aaaAAAaaa';
      final controller = await pumpController(wt, text);

      _searchFor(controller, 'A');
      await wt.pump();

      // Offset 0 is before every match, so the "already on the match" guard
      // is false and the newline goes in.
      controller.selection = const TextSelection.collapsed(offset: 0);
      controller.onEnterKeyAction();

      expect(controller.text, '\naaaAAAaaa');
    });

    testWidgets('inserts a newline with no search visible', (wt) async {
      const text = 'aaa';
      final controller = await pumpController(wt, text);

      controller.selection = const TextSelection.collapsed(offset: 3);
      controller.onEnterKeyAction();

      expect(controller.text, 'aaa\n');
    });

    testWidgets('the full search result drives the navigation state', (
      wt,
    ) async {
      const text = 'aaaAAAaaa';
      final controller = await pumpController(wt, text);

      _searchFor(controller, 'A');
      await wt.pump();

      expect(controller.fullSearchResult.matches, isA<List<SearchMatch>>());
      expect(controller.fullSearchResult.matches.length, 3);

      controller.dismiss();
      await wt.pumpAndSettle();
    });
  });
}
