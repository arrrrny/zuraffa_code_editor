# TDD cycle log — #18 large files render blank lines

Root cause was already pinned by measurement before this log starts; the cycles
below are the test-then-fix order the change actually followed, replayed in a
worktree off `c261235` (master).

## Cycle 1 — red

Goal: a test that fails past ~1000 lines and says why.

Built `test/src/gutter/gutter_line_number_column_width_test.dart` over a
1200-line `CodeField` (400×528 viewport), asserting the invariant rather than a
line count, because the wrap threshold depends on the font's digit advance.

First draft failed to load — `dart format` in a fresh worktree had reformatted
seven files to an obsolete style because `flutter pub get` had not run yet.
Reverted those and re-ran `dart format` on the new file only. **Lesson: run
`flutter pub get` before `dart format` in a new worktree.**

Result:

```
Expected: a numeric value within <0.001> of <24.0>
  Actual: <48.0>
a line number wrapped: the row is 48.0 tall against a code line of 24.0
```

Three tests red (numbers wrap, table height, scroll extent mismatch), one green
(the width guard).

## Cycle 2 — green

Goal: the narrowest change that makes the numbers fit without moving any
gutter whose numbers already fit.

`lib/src/gutter/gutter.dart`:

- number column width = `max(requested − fixedColumns − margin,
  widestVisibleNumberWidth)`, and the gutter width built from that;
- `_widestNumberWidth()` measures the widest visible number in the number style
  with a `TextPainter`;
- the number `Text` is pinned to one line so a row can never be taller than its
  line.

One compile error on the way: `..layout().width` — `layout()` returns `void` in
this Flutter version, so the painter is held in a local and `painter.width`
read from it.

Result: 587 tests green, `dart analyze --fatal-infos` clean,
`dart format --output=none --set-exit-if-changed .` reports 0 changed.

## Cycle 3 — refactor / coverage

Coverage came back at 99.97 % with one uncovered line and one stale exemption:

```
stale line exemption: lib/src/gutter/gutter.dart:165 matches nothing in lcov.info
Coverage 99.97% is below the required 100.00%.
```

Both are the same dead fold-toggle lambda that was already exempted: the code
added above it moved it 165 → 212. Updated the key only; the proof comment and
the exempted-line count (13) are unchanged. Back to 100.00 % (3132/3133 →
3132/3132 after the renumber).

## Cycle 4 — fault injection

Reverted only `lib/src/gutter/gutter.dart`:

```
00:12 +0 -1: the widest visible number fits on one line [E]
00:16 +0 -2: the gutter table is one code line tall per visible row [E]
00:19 +0 -3: the gutter scrolls as far as the code does [E]
00:20 +1 -3: Some tests failed.
```

Tests 1–3 detect the defect, test 4 stays green (it is a guard, not a detector).

## Scratch removed

`test/src/code_field/large_files_probe_test.dart` and
`test/src/code_field/zz_probe_widths_test.dart` — measurement probes, deleted
before committing. `test/coverage_helper_test.dart` and `coverage/` were never
committed.
