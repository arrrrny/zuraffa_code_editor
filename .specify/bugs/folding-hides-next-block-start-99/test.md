# Test: folding-hides-next-block-start-99

- **Verdict**: verified
- **Method**: tdd.verify (mutation reasoning over the new tests) + full-suite regression

## Reproduction, before the fix

`foldAt(2)` on the two-line touching block removed the shared line `      b) {`
from the document. The visible text read `if (a &&` directly followed by `g();`
— the following block's first line, its line number and its fold toggle were
gone. Pinned as the test
`A two-line block that also starts the next one. keeps the shared line on screen
when the block above it is folded`, which failed with:

```
Expected: ...   if (a &&      b) { ...
  Actual: ...   if (a &&\n    g(); ...
```

## Reproduction, after the fix

The shared line survives, glued onto the opener's row:

```
void f() {
  int value = 1;
  if (a &&      b) {
    g();
  }
}
```

The full text is unchanged, and unfolding restores the source byte for byte
(`foldedBlocks` empty).

## Mutation check (does each new test actually bite?)

- Revert the new `else if` branch (hide the line whole): the reproduction test
  fails on the exact reported symptom — proven red before the fix.
- Change the branch's end from `lastLine.textRange.start` to
  `_upstreamEndOfRange(lastLine)`: identical failure, so the pinned text is a
  real assertion and not an accident of the fallback path.
- Widen the guard to `closerOnItsOwnRow >= startOfRange`: the multi-line group's
  `keeps its start visible when the block above it is folded` (which asserts the
  closer keeps its own row and line index 3) fails, so the equality boundary is
  load-bearing.
- `glues the leading-closer two-line shape as before` pins that the pre-existing
  leading-closer fold is unchanged, so the new path cannot silently retarget the
  other shape.

## Gates

- `flutter test` — **720 passed, 0 failed** (715 on master + 5 new). No
  `EXCEPTION CAUGHT` / `Expected:` / `Actual:` output.
- `dart analyze --fatal-infos` — No issues found!
- `dart format --output=none --set-exit-if-changed .` — 283 files, 0 changed
  (the subagent's scratch probe `test/tmp_probe_e_test.dart` was deleted, not
  committed).
- `python3 tool/coverage_gate.py --min 100` —
  **100.00% (3347/3347 lines over 105 files)** — OK.

## Out of scope (recorded, not shipped)

The gutter still has no dedicated row for the following block's toggle in the
two-line glued shape: a `HiddenRange` cannot be empty (`assert(end > start)`),
so a two-line fold always shares a row. Upstream glues `method(){}` the same
way. The issue reports the line being *hidden*, which is fixed.
