import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code_field/search_result_highlighted_builder.dart';
import 'package:zuraffa_code_editor/src/search/match.dart';
import 'package:zuraffa_code_editor/src/search/result.dart';
import 'package:zuraffa_code_editor/src/search/search_navigation_state.dart';

/// When the span being processed carries no style of its own, the highlighted
/// search style has to be built from scratch rather than copied over the
/// existing style — otherwise the match highlight would silently vanish.
void main() {
  test('an unstyled span still gets a highlighted search match', () {
    final builder = SearchResultHighlightedBuilder(
      searchResult: const SearchResult(
        matches: [SearchMatch(start: 0, end: 1)],
      ),
      rootStyle: null,
      textSpan: const TextSpan(children: [TextSpan(text: 'aaa')]),
      searchNavigationState: const SearchNavigationState(totalMatchCount: 1),
    );

    final result = builder.build();

    expect(result.children, isNotEmpty);

    final highlighted = result.children!.cast<TextSpan>().where(
      (span) => span.style?.backgroundColor != null,
    );
    expect(
      highlighted,
      hasLength(1),
      reason: 'the inside of the match keeps a style without inheriting one',
    );
    expect(highlighted.single.text, 'a');
    expect(highlighted.single.style!.color, searchTextColor);
  });
}
