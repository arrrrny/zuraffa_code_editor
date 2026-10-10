import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/search/settings.dart';

import '../common/create_app.dart';

/// After the user edits the text of a searched document the navigation state
/// loses its remembered match index (`resetCurrentMatchIndex`) while the
/// controller keeps its last full — and still populated — search result.
/// `moveNext()` then has to recompute the index from scratch instead of reading
/// it off the state, which is what the `??` chain in `_moveToResult` covers.
///
/// The assertions are deliberately made before the next pump: the search field
/// widget only clears its own pattern on the rebuild that follows, and the
/// point of the test is the state the edit leaves behind.
void main() {
  testWidgets('moveNext() recomputes the index after an edit', (wt) async {
    const text = 'Aaa';
    final codeController = await pumpController(wt, text);
    codeController.selection = const TextSelection.collapsed(offset: 0);

    codeController.showSearch();

    final navigationController =
        codeController.searchController.navigationController;

    codeController.searchController.settingsController.value =
        const SearchSettings(
          isCaseSensitive: false,
          isRegExp: false,
          pattern: 'a',
        );

    expect(navigationController.value.currentMatchIndex, 0);
    expect(navigationController.value.totalMatchCount, 3);

    codeController.text = 'Aaaa';

    expect(navigationController.value.currentMatchIndex, isNull);
    expect(navigationController.value.totalMatchCount, 4);
    expect(codeController.fullSearchResult.matches.length, 4);

    navigationController.moveNext();

    // The recomputed index is the next match after the caret, wrapped back
    // around the match list.
    expect(navigationController.value.currentMatchIndex, 1);
    expect(navigationController.value.totalMatchCount, 4);
    expect(
      codeController.selection,
      const TextSelection(baseOffset: 1, extentOffset: 2),
    );

    await wt.pumpAndSettle();
  });
}
