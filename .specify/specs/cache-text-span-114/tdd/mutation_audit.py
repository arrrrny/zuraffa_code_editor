import hashlib
import os
import subprocess

"""Mutation audit for the span cache.

One mutant at a time is applied to lib/src/code_field/code_controller.dart,
the cache test file is run, and the mutant is killed iff some test fails.
A mutant that does not compile is not a kill: the run is reported UNRESOLVED
and must be fixed, not counted.

Dropped on purpose, with reasons, rather than bent into existence:

- M-noLastTextSpan (return the cached span without assigning `lastTextSpan`).
  A no-op. The miss path writes `_cachedTextSpan` and `lastTextSpan` together,
  so the object a hit returns is always the object `lastTextSpan` already holds.
  No test of `lastTextSpan` can see the difference.
- M-buildBeforeCheck (build the tree before comparing the key). Not a mutant of
  this implementation: the committed code already compares first, so the `old`
  pattern does not exist. It is also unobservable — a discarded extra build
  produces the same trees and the same objects.

Two mutants survive only under masking, and the tests are shaped around it:

- The navigation half of the key is `currentMatchIndex`, not the
  `SearchNavigationState` object. The state implements no `==`, and the
  controller hands out a new instance on every pattern change and every move,
  so keying on the object would invalidate on things the tree never shows.
- `setLanguage` rebuilds `_code`, so no test can change the language without
  also changing the code, so M-noLanguageKey cannot be isolated by a language
  change. `Mode()` as its replacement is also a fresh instance per key build,
  so that mutant is killed by the plain repeated-call hit instead.
"""

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
    # the old font size. The `code` line above is part of the pattern because a
    # bare `      style: style,` also matches the 8-space composing branch and
    # the SpanBuilder call -- an audit that replaces the first of those mutates
    # the wrong line and reports a phantom survivor.
    'M-noStyleKey': (
        CC,
        "      code: _code,\n      style: style,",
        "      code: _code,\n      style: const TextStyle(),",
    ),
    # M-noCodeKey: `_code` is not part of the key. A stale tree survives a
    # keystroke, a fold and an unfold.
    'M-noCodeKey': (
        CC,
        "    final spanCacheKey = (\n      code: _code,",
        "    final spanCacheKey = (\n      code: Code.empty,",
    ),
    # M-noSearchKey: the search result is not part of the key. Killed by the
    # test that swaps one pattern for another with the current match in the
    # same place, so the navigation half cannot answer for it.
    'M-noSearchKey': (
        CC,
        "      language: _language,\n      searchResult: visibleSearchResult,",
        "      language: _language,\n      searchResult: SearchResult.empty,",
    ),
    # M-noNavKey: the current match is not part of the key, which is the half
    # of the navigation state the rendered tree depends on: the highlight
    # builder reads `currentMatchIndex` and nothing else from it.
    'M-noNavKey': (
        CC,
        "      currentMatchIndex: _searchNavigationController.value.currentMatchIndex,",
        "      currentMatchIndex: null,",
    ),
    # M-noLanguageKey: the language is not part of the key. Every key component
    # after it is one the tests assert; this one guards the branch that chooses
    # the builder at all. `Mode()` is a fresh instance on every key build, so
    # the key never compares equal and the cache never hits at all.
    'M-noLanguageKey': (
        CC,
        "      language: _language,",
        "      language: Mode(),",
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
}

results = {}
for name, (path, old, new) in MUTANTS.items():
    assert old in ORIG[path], name + ': pattern not found in ' + path
    # An ambiguous pattern silently mutates the wrong line: the audit then
    # reports a survivor that says nothing about the key.
    assert (
        ORIG[path].count(old) == 1
    ), name + ': pattern is not unique in ' + path
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
