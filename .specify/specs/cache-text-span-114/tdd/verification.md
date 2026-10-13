# Verification: cache-text-span-114

Verdict: **PASS** — 9/9 mutants killed, no survivors, 100% line coverage.

## Scope

`CodeController.buildTextSpan` returns the object the previous call returned when
nothing the build reads has changed. It is what `EditableText` calls to obtain
the text it paints, and Flutter calls it on every rebuild: a selection move, a
focus change, any parent rebuild. Each call re-ran `SpanBuilder` over the parsed
highlight tree and flattened it again through `SearchResultHighlightedBuilder`.

Closes the repository's own TODO at the site:
`// TODO(alexeyinkin): Return cached if the value did not change, …`.

## Evidence

| Gate | Result |
| --- | --- |
| `dart analyze --fatal-infos lib test` | No issues found |
| `dart format --output=none --set-exit-if-changed .` | 0 changed (309 files) |
| `flutter test --concurrency=2` | 909 green (907 on master + 2 new tests) |
| `tool/coverage_gate.py --min 100` | **100.00% (3562/3562 lines over 109 files), 9 pre-existing exemptions, none added** |

The one host-speed flake (`no_language_keystroke_test.dart:257`, absolute 100 ms
bound) did not fire on the final run; it is unrelated to this change and its bound
was not widened. See the perf note in `scala-multiline-imports-117` for the
control measurements.

## RED

All 16 tests in `test/src/code_field/build_text_span_cache_test.dart` were run
against the pre-feature controller (`code_controller.dart` from master,
`0d37400`): **`00:08 +1 -15: Some tests failed.`** — 15 of 16 failed, every one
on its first assertion, the hit assertions, because there is no cache to hit.

The single pass is the honest lesson of the cycle: "the composing path is not
served from the cache" asserts `identical(composing, again)` is **false**, and a
no-cache implementation satisfies that trivially. Its REVERSE is what the
implementation makes true — that is the test's actual content — but as written
it cannot distinguish the feature from its absence, only from a hypothetical
future that caches the composing span. It is kept as the pin for that future,
not as RED evidence.

The two audit-derived tests ("dropping the language invalidates", "a second
pattern with the same current match invalidates") are in the 15: their baseline
hit assertions fail the same way.

## Mutation testing

`tdd/mutation_audit.py` — one mutant at a time, the cache test file run against
it, originals restored byte-identical after every run.

| Mutant | Target | Verdict |
| --- | --- | --- |
| M-noHit | `if (spanCacheKey == _spanCacheKey)` → `if (false)` | KILLED |
| M-getThemeKey | key the fabricated `_getTheme(context)` instead of `CodeTheme.of(context)` | KILLED |
| M-noStyleKey | `style: style` → `style: const TextStyle()` | KILLED |
| M-noCodeKey | `code: _code` → `code: Code.empty` | KILLED |
| M-noSearchKey | `searchResult: visibleSearchResult` → `SearchResult.empty` | KILLED |
| M-noNavKey | `currentMatchIndex: …currentMatchIndex` → `null` | KILLED |
| M-noLanguageKey | `language: _language` → `Mode()` | KILLED |
| M-cacheAboveComposing | composing guard moved below the lookup | KILLED |
| M-noKeyStore | `_spanCacheKey = spanCacheKey` deleted | KILLED |

Two mutants were **dropped as proven no-ops rather than kept as survivors**, and
the reasoning is recorded in the script:

- **M-noLastTextSpan** — a hit returning `_cachedTextSpan!` without assigning
  `lastTextSpan`. The miss path writes both fields together, so the object a hit
  returns is always the object `lastTextSpan` already holds. No test of
  `lastTextSpan` can see the difference.
- **M-buildBeforeCheck** — building the tree before comparing the key. Its `old`
  pattern does not exist in this implementation (the committed code already
  compares first), so it is not a mutant of it; it is also unobservable, since a
  discarded extra build produces the same trees and the same objects.

## The finding the audit produced

The audit's first run reported two survivors — **M-noStyleKey** and
**M-noCodeKey** — that were not test vacuity but an audit bug: the script's
`old` patterns were bare 6-space-indented substrings, which also match inside
8- and 10-space lines elsewhere in the file, so the first mutant had been
rewriting the composing branch's `super.buildTextSpan(style: style)` and the
other an unrelated `code: _code` site. Patterns are now anchored with unique
context, and the script asserts each pattern occurs exactly once before it uses
it.

With the patterns fixed, the real finding surfaced: **M-noSearchKey survived**
until the navigation half of the key was corrected. The key had held the whole
`SearchNavigationState` object. That class implements no `==`, and
`SearchNavigationController` assigns a new instance on every change of the search
result and on every `moveNext`/`movePrevious`, so the navigation half invalidated
on its own for every pattern change — and while it did, removing the search result
from the key entirely was unobservable. The highlight builder reads nothing from
the navigation state but `currentMatchIndex`
(`search_result_highlighted_builder.dart:31-34`), so the key now holds exactly
that. The over-invalidation was also a real, if silent, cost: toggling a pattern
away and back produced identical inputs but a new navigation object, so the cache
missed on trees it had already built.

The test that kills M-noSearchKey is the one that swaps `a` for `Aa` over
`'int Aa = 1;\nint ab = 2;\n'`: both patterns leave the current match at index 0,
so the navigation half is equal across the two calls and the match set is the
only component that can tell them apart.

## Coverage

`tool/coverage_gate.py` at 100% — 3562/3562 lines over 109 files, log at
`/tmp/gate114b.log`. The 9 pre-existing exemptions are unchanged in count and in
line number: the feature adds no uncovered branch, and the import removal shifted
no line the gate pins. The branches it does add (`hasActiveComposition` early
return, key hit/miss) are covered by the 16 tests.

## Notes

- `setLanguage` rebuilds `_code`, so no test can change the language without
  also changing the code. The `language` component of the key is therefore
  masked by the `code` component in any language-change test, and M-noLanguageKey
  is killed on the never-hit property of `Mode()` (a fresh instance per key
  build) rather than by that test. Recorded rather than papered over.
