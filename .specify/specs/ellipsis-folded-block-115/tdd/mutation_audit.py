import hashlib
import os
import subprocess

WT = os.path.abspath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..')
)

SB = WT + '/lib/src/code_field/span_builder.dart'
CC = WT + '/lib/src/code_field/code_controller.dart'
TEST = 'test/src/code_field/fold_ellipsis_test.dart'

ORIG = {p: open(p).read() for p in (SB, CC)}
DIGEST = {p: hashlib.sha256(t.encode()).hexdigest() for p, t in ORIG.items()}


def digest(path):
    return hashlib.sha256(open(path).read().encode()).hexdigest()


FINAL_APPEND = "        TextSpan(text: _foldEllipsis, style: rootStyle),"
SPLICE = "        TextSpan(text: _foldEllipsis, style: rootStyle ?? span.style),"

SPLICE_RETURN = """    return TextSpan(
      style: span.style,
      children: [
        TextSpan(text: text.substring(0, runStart), style: span.style),
        // Children render after the node's own text, which is a newline: they
        // are already on the following line, so they stay behind the marker.
        ...?span.children,
        TextSpan(text: _foldEllipsis, style: rootStyle ?? span.style),
        TextSpan(text: text.substring(runStart), style: span.style),
      ],
    );"""

NULL_GUARD = """      if (visible != null) {
        result.add(visible);
      }"""

MUTANTS = {
    # M-noSplice: the terminating-node splice fires but paints 'x' instead.
    'M-noSplice': (SB, SPLICE, SPLICE.replace("_foldEllipsis", "'x'")),
    # M-noFinalSplice: the final-line append paints 'x'. The two splice sites
    # are separate code paths, so each needs its own mutant.
    'M-noFinalSplice': (SB, FINAL_APPEND, FINAL_APPEND.replace("_foldEllipsis", "'x'")),
    # M-afterNewline: the marker is placed after the terminating node's own
    # text -- which is the newline -- so it lands at the start of the next row
    # instead of at the end of the kept line.
    'M-afterNewline': (
        SB,
        SPLICE_RETURN,
        """    return TextSpan(
      style: span.style,
      children: [
        TextSpan(text: text.substring(0, runStart), style: span.style),
        // Children render after the node's own text, which is a newline: they
        // are already on the following line, so they stay behind the marker.
        ...?span.children,
        TextSpan(text: text.substring(runStart), style: span.style),
        TextSpan(text: _foldEllipsis, style: rootStyle ?? span.style),
      ],
    );""",
    ),
    # M-lineZero: only line 0 can be a kept line. Passes every fixture whose
    # kept line happens to be line 0 and fails the rest.
    'M-lineZero': (
        SB,
        "if (!_foldedKeptLines.contains(_visibleLineIndex - 1)) {",
        "if (!_foldedKeptLines.contains(0)) {",
    ),
    # M-foldableNotFolded: derive from what *can* be folded instead of what is,
    # so the marker survives an unfold and appears on lines that were never
    # folded at all.
    'M-foldableNotFolded': (
        SB,
        "for (final block in code.foldedBlocks) {",
        "for (final block in code.foldableBlocks) {",
    ),
    # M-tokenStyle: the marker always borrows the style of the text it follows.
    'M-tokenStyle': (SB, "rootStyle ?? span.style", "span.style"),
    # M-keepNulls: the nulls from cutLineIndexIfVisible are not discarded, so a
    # swallowed inner fold resolves to line 0 and gets a marker it does not
    # deserve.
    'M-keepNulls': (
        SB,
        NULL_GUARD,
        "      result.add(visible ?? 0);",
    ),
    # M-dropKeptLineCheck: the kept-line check is gone from the final-line
    # path, so the marker closes the tree of a document that folds nothing.
    'M-dropKeptLineCheck': (
        SB,
        "!_foldedKeptLines.contains(_visibleLineIndex)",
        "false",
    ),
    # M-noFinalSearchGate: the search switch holds the terminating-node splice
    # but not the final-line append, so a match after a fold whose kept line is
    # the last visible line is shifted again.
    'M-noFinalSearchGate': (
        SB,
        "if (!withFoldEllipsis || !_foldedKeptLines.contains(_visibleLineIndex)) {",
        "if (!_foldedKeptLines.contains(_visibleLineIndex)) {",
    ),
    # M-noSearchSwitch: the search suppression is dropped, so a match after a
    # fold lands two characters early again.
    'M-noSearchSwitch': (
        CC,
        "withFoldEllipsis: visibleSearchResult.matches.isEmpty",
        "withFoldEllipsis: true",
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
    unresolved = [l for l in out.splitlines() if 'UnimplementedError' in l or 'Failed to load' in l]
    results[name] = (killed, failed, unresolved)
    print(
        '=== %s === %s'
        % (name, 'KILLED' if killed else 'SURVIVED')
    )
    for f in failed:
        print('   failed: %s' % f)
    if unresolved:
        print('   UNRESOLVED (compile/load error, not a valid kill): %s' % unresolved[:1])
    if not killed:
        print('   raw tail: %s' % out.strip().splitlines()[-1])

    open(path, 'w').write(ORIG[path])

for p, t in ORIG.items():
    assert digest(p) == DIGEST[p], 'RESTORE FAILED for ' + p
    open(p, 'w').write(t)
print('\nall originals restored byte-identical: %s' % all(digest(p) == DIGEST[p] for p in ORIG))
print('summary: %d/%d killed' % (sum(1 for k, _, _ in results.values() if k), len(results)))
