# Plan: cache-text-span

## Implementation outline

One file changes: `lib/src/code_field/code_controller.dart`.

1. Add a private record type alias for the key, above the class, with the doc
   explaining why it is a record (`data-model.md` §The state).
2. Add two private fields to the class: `_spanCacheKey` (`_SpanCacheKey?`) and
   `_cachedTextSpan` (`TextSpan?`).
3. In `buildTextSpan`, after the composing early-return, build the key from
   `_code`, `style`, `CodeTheme.of(context)`, `_language`,
   `visibleSearchResult` and `_searchNavigationController.value`, and return the
   cached span when it compares equal.
4. On a miss, build exactly as today, then store key and span, assign
   `lastTextSpan`, and return.
5. Fix the `lastTextSpan` doc comment: "the updated text was actually requested
   by the widget" is no longer a valid inference once a hit exists.

No new file under `lib/`. No new export. No change to `_createTextSpan`,
`_getTheme`, `SpanBuilder`, `SearchResultHighlightedBuilder` or `Code`.

## The shape of the change

```dart
/// Every input [buildTextSpan] reads, in one value.
///
/// A record so the comparison is the language's own structural `==`: the two
/// components that define value equality ([TextStyle], [SearchResult]) compare
/// by value, and the four that do not ([Code], [CodeThemeData], [Mode],
/// [SearchNavigationState]) compare by identity — which is the semantics each
/// of them actually has, and exactly what a hit needs.
typedef _SpanCacheKey = (
  Code code,
  TextStyle? style,
  CodeThemeData? theme,
  Mode? language,
  SearchResult searchResult,
  SearchNavigationState searchNavigationState,
);
```

```dart
  _SpanCacheKey? _spanCacheKey;
  TextSpan? _cachedTextSpan;
```

```dart
    final visibleSearchResult = _code.hiddenRanges.cutSearchResult(
      fullSearchResult,
    );

    // `CodeTheme.of(context)`, not `_getTheme(context)`: the latter fabricates a
    // fresh `CodeThemeData` when no `CodeTheme` is in scope and that class has no
    // `==`, so keying on the fabricated object would make every call a miss —
    // silently, since a cache that never hits is not observable.
    final spanCacheKey = (
      code: _code,
      style: style,
      theme: CodeTheme.of(context),
      language: _language,
      searchResult: visibleSearchResult,
      searchNavigationState: _searchNavigationController.value,
    );

    if (spanCacheKey == _spanCacheKey) {
      return lastTextSpan = _cachedTextSpan!;
    }

    final span = SearchResultHighlightedBuilder(
      searchResult: visibleSearchResult,
      rootStyle: style,
      textSpan: _createTextSpan(
        context: context,
        style: style,
        withFoldEllipsis: visibleSearchResult.matches.isEmpty,
      ),
      searchNavigationState: _searchNavigationController.value,
    ).build();

    _spanCacheKey = spanCacheKey;
    _cachedTextSpan = span;
    return lastTextSpan = span;
```

Three places worth naming because they are where a wrong version of this change
goes bad:

- **The hit path assigns `lastTextSpan`.** Skipping it makes `lastTextSpan` stale
  the first time anything but this controller writes to it, and FR-12 is the test
  that catches it.
- **`_createTextSpan` is constructed inside the builder argument, not hoisted.**
  Hoisting it above the key check would rebuild the tree before knowing whether
  it is needed — the entire win of the change, spent on the hit path.
- **The key is built from `CodeTheme.of(context)`, not from `_getTheme(context)`.**
  See R3. A mutation removes this distinction; FR-6's "no theme ancestor" case is
  what proves it.

## Tests

`test/src/code_field/build_text_span_cache_test.dart`, written RED before the
change. Grouped by the component of the key they attack, so a missing component
shows up as its own failing group rather than as a mystery:

| Group | Covers |
| --- | --- |
| a repeated call | FR-1, FR-2 |
| the text and the fold state | FR-3, FR-4 |
| the style | FR-5 |
| the theme | FR-6, and the no-ancestor case R3 warns about |
| the search state | FR-7, FR-9 |
| the language | FR-8 |
| IME composition | FR-10 |
| what a hit returns | FR-11, FR-12 |
| no language | FR-13 |

Fixture: `test/src/common/create_app.dart` (`pumpController`), plus an unwrapped
variant for the no-theme case and a `CodeTheme`-wrapped variant. The search group
drives `controller.searchController.settingsController` and
`controller.searchController.navigationController`, the way
`test/src/search/search_settings_test.dart` and
`test/src/search/search_navigation_test.dart` do.

## Complexity budget

- Net change to `buildTextSpan`: the key construction, one `if`, and the store —
  no new method, no helper, no abstraction over "cacheable".
- One private record type alias. No class, no interface, no strategy, no
  `ValueNotifier`.
- Zero new public identifiers. The alias is private, so no doc-comment is
  published and no export list changes.
- No test helpers beyond the two widget wrappers. No mock of `EditableText`.

## Conformance

`.specify/specs/cache-text-span-114/code_matrix.md` — every FR/SC, the artifact
that satisfies it, and the test that proves it.
