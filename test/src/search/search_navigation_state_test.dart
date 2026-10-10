import 'package:zuraffa_code_editor/src/search/search_navigation_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchNavigationState', () {
    test('copyWith keeps the values it is not given', () {
      const state = SearchNavigationState(
        currentMatchIndex: 2,
        totalMatchCount: 7,
      );

      final copied = state.copyWith(currentMatchIndex: 4);

      expect(copied.currentMatchIndex, 4);
      expect(copied.totalMatchCount, 7, reason: 'an absent field is inherited');
    });

    test('copyWith can carry the match count on its own', () {
      const state = SearchNavigationState(
        currentMatchIndex: 2,
        totalMatchCount: 7,
      );

      final copied = state.copyWith(totalMatchCount: 3);

      expect(copied.totalMatchCount, 3);
      expect(copied.currentMatchIndex, 2);
    });

    test('copyWith with nothing given returns an equivalent state', () {
      const state = SearchNavigationState(
        currentMatchIndex: 2,
        totalMatchCount: 7,
      );

      final copied = state.copyWith();

      expect(copied.currentMatchIndex, 2);
      expect(copied.totalMatchCount, 7);
    });

    test('a null field is inherited rather than replaced', () {
      const state = SearchNavigationState(
        currentMatchIndex: 1,
        totalMatchCount: 2,
      );

      expect(state.copyWith(currentMatchIndex: null).currentMatchIndex, 1);
      expect(state.resetCurrentMatchIndex(null).totalMatchCount, 2);
    });
  });
}
