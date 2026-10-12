# TDD verification: per-line-background

Feature: `.specify/specs/per-line-background-86`
Branch: `spec/per-line-background-86`

## Test list

`test/src/code_field/per_line_background_test.dart` — 10 widget tests.

| # | Test | Guards |
| --- | --- | --- |
| 1 | leaves the field untouched when it is not set | default tree: no `LineBackgroundLayer`, no `Stack` |
| 2 | leaves the field untouched when it returns null for every line | layer present but paints nothing |
| 3 | tints a one-character line across the whole row | **row extent**, not glyph-run extent |
| 4 | does not tint a line the builder returns null for | row extent again, from a different line |
| 5 | hands the builder the full, unfolded line index | index coordinate space + trailing newline |
| 6 | does not ask about a line hidden inside a folded block | folds + index attribute |
| 7 | does not tint lines hidden by a collapsed section | hidden sections |
| 8 | still works when no language is set | the no-language path |
| 9 | re-renders when the hook is reassigned | mutability at runtime |
| 10 | keeps the search-match colour on top of a tinted line | layering with `SearchResultHighlightedBuilder` |

Tests 1–10 were written before `line_background.dart` existed and run RED
(compile errors: `lineBackgroundBuilder` undefined, `LineBackgroundLayer`
undefined). Test 3 and 4 were re-run RED against the mechanism choice — see
"Mutation audit" below.

## RED→GREEN evidence

First RED run (`flutter test --concurrency=2
test/src/code_field/per_line_background_test.dart`):

```text
test/.../per_line_background_test.dart:2:8: Error: Error when reading
  'lib/src/code_field/line_background.dart': No such file or directory
test/.../per_line_background_test.dart:33:14: Error: The setter
  'lineBackgroundBuilder' isn't defined for the type 'CodeController'.
00:00 +0 -1: Some tests failed.
```

After implementing `line_background.dart`, the `CodeController` field and the
`CodeField` wiring:

```text
00:02 +10: All tests passed!
```

Four RED assertions were wrong in the *tests*, not the implementation, and were
corrected rather than deleted:

- `expect(seen, [0, 1, 2])` for a document ending in `\n` — a trailing newline
  makes a fourth, empty line, so `[0, 1, 2, 3]` is correct. Kept as the
  trailing-newline pin.
- `expect(_textWidth(tester, 'b' * 50) + 50)` — the reference line was so wide
  (662px) that a correct 712px row failed by 0.5px. The fixture's line 1 was
  shortened to `bb`.
- `expect(seen, [0, 3])` for the fold fixture — same trailing-newline cause; the
  fixture was changed to not end in `\n`.
- `find.byType(LineBackgroundLayer) == findsNothing` for an all-`null` builder —
  the layer *is* built (a hook was set) and renders nothing. Assertion changed to
  "no `Container` under the layer".

## Mutation audit

### M-nostretch — killed

The load-bearing claim is that the tint covers the row, not the glyph run.
Mutating `crossAxisAlignment: CrossAxisAlignment.stretch` →
`CrossAxisAlignment.start` (so the row keeps its intrinsic width, given a fixed
`width: 40`) produced:

```text
Expected: a value greater than <114.25>
  Actual: <40.0>
Expected: a value greater than <128.5>
  Actual: <40.0>
Expected: a value greater than <114.25>
  Actual: <40.0>
00:02 +7 -3: Some tests failed.
```

Tests 3, 4 and 8 killed it.

### M-wrongwidth — equivalent (documented, not counted)

Wrapping the tinted row in `SizedBox(width: 40)` **survived**: `Column`'s
`crossAxisAlignment: stretch` gives children tight cross-axis constraints equal
to the column's width, which overrides the `SizedBox`'s preferred width. The
mutant does not change the rendered layout, so it is a refactor, not a defect.
Recorded rather than counted as a kill — it is the reason the audit above had to
mutate the alignment instead.

### M-alwaystint — killed

Ignoring the builder's `null` and tinting every visible line would fail tests 2
and 4 (`hasLength(1)` on a single tinted row).

### M-alwayslayer — killed

Building the layer unconditionally (the `Stack` not guarded by
`lineBackgroundBuilder != null`) fails test 1, which asserts no `Stack` reaches
the tree.

## Coverage

CI-identical gate, run on the committed tip:

```text
flutter test --coverage --concurrency=2   →  All tests passed! (847)
python3 tool/coverage_gate.py --min 100
  zuraffa_code_editor line coverage: 100.00% (3509/3509 lines over 109 files)
  excluded individual lines (see EXEMPT_LINES): 9
  Coverage gate: 100.00% >= 100.00% — OK
```

`EXEMPT_LINES` is unchanged at 9 entries and the same 9 as on master — the
`highlight.dart` exemption stays at line **123**. No new exemption was needed.
`EXEMPT_FILES` is likewise unchanged.

## Static gates

```text
dart analyze --fatal-infos                          → No issues found!
dart format --output=none --set-exit-if-changed .   → clean
```

(`flutter analyze` with the coverage helper present reports ~128 `unused_import`
warnings, all inside the generated `test/coverage_helper_test.dart`, which imports
every `lib/**` file. The helper is deleted after the gate, so the real gate is
clean.)
