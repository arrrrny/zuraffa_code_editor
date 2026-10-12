import hashlib
import os
import subprocess

WT = os.path.abspath(
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..'
    )
)

CC = WT + '/lib/src/code_field/code_controller.dart'
TEST = 'test/src/code_field/build_text_span_cache_test.dart'

ORIG = {p: open(p).read() for p in (CC,)}
DIGEST = {p: hashlib.sha256(t.encode()).hexdigest() for p, t in ORIG.items()}


def digest(path):
    return hashlib.sha256(open(path).read().encode()).hexdigest()


HIT = "    if (spanCacheKey == _spanCacheKey) {"
THEME_KEY = "      theme: CodeTheme.of(context),"

MUTANTS = {
    # M-noHit: the hit return is gone, so every call rebuilds. This is the
    # whole feature, and it is the only mutant that has to die on all of them.
    'M-noHit': (
        CC,
        HIT,
        "    if (false) {",
    ),
    # M-getThemeKey: key on the theme the controller fabricates instead of the
    # one in scope. `_getTheme` returns a fresh `CodeThemeData` when no
    # `CodeTheme` is an ancestor and that class implements no `==`, so the key
    # never compares equal -- the cache silently never hits for every field
    # without a theme, which is most of them.
    'M-getThemeKey': (
        CC,
        THEME_KEY,
        "      theme: _getTheme(context),",
    ),
    # M-noStyleKey: the style is not part of the key. A stale tree is painted at
    # the old font size.
    'M-noStyleKey': (
        CC,
        "      style: style,",
        "      style: const TextStyle(),",
    ),
    # M-noCodeKey: `_code` is not part of the key. A stale tree survives a
    # keystroke, a fold and an unfold.
    'M-noCodeKey': (
        CC,
        "      code: _code,",
        "      code: Code.empty,",
    ),
    # M-noSearchKey: the search result is not part of the key, so the highlight
    # never appears and never disappears.
    'M-noSearchKey': (
        CC,
        "      searchResult: visibleSearchResult,",
        "      searchResult: SearchResult.empty,",
    ),
    # M-noNavKey: only the *current* match is missing from the key, which is the
    # half of the search state that a "result has not changed" check misses.
    'M-noNavKey': (
        CC,
        "      searchNavigationState: _searchNavigationController.value,",
        "      searchNavigationState: const SearchNavigationState.noMatches,",
    ),
    # M-noLanguageKey: the language is not part of the key. Every key component
    # after it is one the tests assert; this one guards the branch that chooses
    # the builder at all.
    'M-noLanguageKey': (
        CC,
        "      language: _language,",
        "      language: Mode(),",
    ),
    # M-noLastTextSpan: a hit returns the cached span without recording it, so
    # `lastTextSpan` drifts from what was served.
    'M-noLastTextSpan': (
        CC,
        "      return lastTextSpan = _cachedTextSpan!;",
        "      return _cachedTextSpan!;",
    ),
    # M-cacheAboveComposing: the composing guard is moved below the lookup, so
    # a composing range is served a cached, non-composing span. `hasActiveComposition`
    # is not a key component, by design -- this is what would happen if the
    # guard were not above the cache.
    'M-cacheAboveComposing': (
        CC,
        """    if (hasActiveComposition) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing ?? true,
      );
    }

    final visibleSearchResult""",
        """    final visibleSearchResult""",
    ),
    # M-noKeyStore: the span is cached but the key is not, so the next call
    # compares against a stale key and never hits.
    'M-noKeyStore': (
        CC,
        "    _spanCacheKey = spanCacheKey;",
        "",
    ),
    # M-buildBeforeCheck: the tree is built before the key is compared, so a hit
    # pays for the whole walk it exists to skip.
    'M-buildBeforeCheck': (
        CC,
        """    if (spanCacheKey == _spanCacheKey) {
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
    ).build();""",
        """    final span = SearchResultHighlightedBuilder(
      searchResult: visibleSearchResult,
      rootStyle: style,
      textSpan: _createTextSpan(
        context: context,
        style: style,
        withFoldEllipsis: visibleSearchResult.matches.isEmpty,
      ),
      searchNavigationState: _searchNavigationController.value,
    ).build();

    if (spanCacheKey == _spanCacheKey) {
      return lastTextSpan = _cachedTextSpan!;
    }""",
    ),
}

results = {}
for name, (path, old, new) in MUTANTS.items():
    assert old in ORIG[path], name + ': pattern not found in ' + path
    assert old != new, name + ': pattern is a no-op'
    open(path, 'w').write(ORIG[path].replace(old, new, 1))

    run = subprocess.run(
        ['flutter', 'test', '--concurrency=2', TEST],
        cwd=WT,
        capture_output=True,
        text=True,
    )
    out = run.stdout + run.stderr
    killed = 'Some tests failed' in out
    failed = [
        l.split(': ', 1)[1].split(' [E]')[0]
        for l in out.splitlines()
        if ' [E]' in l and 'test/src' in l
    ]
    unresolved = [
        l for l in out.splitlines() if 'UnimplementedError' in l or 'Failed to load' in l
    ]
    results[name] = (killed, failed, unresolved)
    print('=== %s === %s' % (name, 'KILLED' if killed else 'SURVIVED'))
    for f in failed:
        print('   failed: %s' % f)
    if unresolved:
        print(
            '   UNRESOLVED (compile/load error, not a valid kill): %s'
            % unresolved[:1]
        )
    if not killed:
        print('   raw tail: %s' % out.strip().splitlines()[-1])

    open(path, 'w').write(ORIG[path])

for p, t in ORIG.items():
    assert digest(p) == DIGEST[p], 'RESTORE FAILED for ' + p
    open(p, 'w').write(t)
print(
    '\nall originals restored byte-identical: %s'
    % all(digest(p) == DIGEST[p] for p in ORIG)
)
print(
    'summary: %d/%d killed'
    % (sum(1 for k, _, _ in results.values() if k), len(results))
)
