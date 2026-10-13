import hashlib
import os
import subprocess

"""Mutation audit for the merged invariant and the recovery simplification.

One mutant at a time is applied to lib/src/hidden_ranges/hidden_ranges.dart,
the hidden_ranges suite is run, and the mutant is killed iff some test fails.
A mutant that does not compile is not a kill: the run is reported UNRESOLVED
and must be fixed, not counted.

Every `old` pattern is anchored well enough that it occurs exactly once in the
file — an ambiguous pattern rewrites an unintended line and the audit then
reports a survivor that says nothing about the invariant. The runner asserts
the count before using a pattern (the lesson from cache-text-span-114, whose
first two "survivors" were its own bare-substring patterns matching inside
differently-indented lines).
"""

WT = os.path.abspath(
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..'
    )
)

HR = WT + '/lib/src/hidden_ranges/hidden_ranges.dart'
TEST_DIR = 'test/src/hidden_ranges'

ORIG = {p: open(p).read() for p in (HR,)}
DIGEST = {p: hashlib.sha256(t.encode()).hexdigest() for p, t in ORIG.items()}


def digest(path):
    return hashlib.sha256(open(path).read().encode()).hexdigest()


ASSERT_PREDICATE = "      if (ranges[i].start <= ranges[i - 1].end) {\n        return false;\n      }"

MUTANTS = {
    # M1: the assert fails only on overlap, so touching ranges -- the shape the
    # tightened invariant exists to refuse -- construct again.
    'M1-overlapOnly': (
        HR,
        "      if (ranges[i].start <= ranges[i - 1].end) {",
        "      if (ranges[i].start < ranges[i - 1].end) {",
    ),
    # M2: the assert fails only on adjacency, so overlapping ranges construct.
    # The rejection is `==` — an overlapping pair has start < previous end, so
    # it sails past.
    'M2-adjacencyOnly': (
        HR,
        "      if (ranges[i].start <= ranges[i - 1].end) {",
        "      if (ranges[i].start == ranges[i - 1].end) {",
    ),
    # M3: the assert is gone entirely, so both shapes construct. The assert is
    # the invariant; without it nothing else in the file notices. The initializer
    # keeps its `:` — the pattern starts there, so the replacement must carry it
    # or the constructor stops compiling and the "kill" is just a load error.
    'M3-noAssert': (
        HR,
        """    : assert(
        _areSortedMergedAndNonAdjacent(ranges),
        'Ranges must be sorted, non-overlapping and non-adjacent. '
        '`HiddenRangesBuilder` merges touching ranges, so a list that '
        'reaches here with `ranges[i].start == ranges[i - 1].end` was '
        'not built by it.',
      ),
""",
        "    :",
    ),
    # M4: the predicate accepts everything, which is M3 with the loop kept.
    'M4-predicateAlwaysTrue': (
        HR,
        ASSERT_PREDICATE,
        "",
    ),
    # M5: downstream recovers the end of the range instead of its start, so a
    # collapsed position recovers past the hidden characters it must skip.
    'M5-downstreamReturnsEnd': (
        HR,
        """            case TextAffinity.downstream:
              return range.start;""",
        """            case TextAffinity.downstream:
              return range.end;""",
    ),
    # M6: upstream recovers the start instead of the end.
    'M6-upstreamReturnsStart': (
        HR,
        """            case TextAffinity.upstream:
              return range.end;""",
        """            case TextAffinity.upstream:
              return range.start;""",
    ),
    # M7: downstream always returns the FIRST range's start. The first- and
    # middle-collapse cases cannot tell this from M5's target; the middle and
    # last ones can.
    'M7-downstreamAlwaysFirst': (
        HR,
        """            case TextAffinity.downstream:
              return range.start;""",
        """            case TextAffinity.downstream:
              return ranges[0].start;""",
    ),
    # M8: upstream always returns the LAST range's end.
    'M8-upstreamAlwaysLast': (
        HR,
        """            case TextAffinity.upstream:
              return range.end;""",
        """            case TextAffinity.upstream:
              return ranges.last.end;""",
    ),
}

results = {}
for name, (path, old, new) in MUTANTS.items():
    assert old in ORIG[path], name + ': pattern not found in ' + path
    assert (
        ORIG[path].count(old) == 1
    ), name + ': pattern is not unique in ' + path
    assert old != new, name + ': pattern is a no-op'
    open(path, 'w').write(ORIG[path].replace(old, new, 1))

    run = subprocess.run(
        ['flutter', 'test', '--concurrency=2', TEST_DIR],
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
