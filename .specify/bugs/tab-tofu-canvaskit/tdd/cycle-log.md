# TDD cycle log — #20 Tab tofu in CanvasKit

## Triage

The issue blames CanvasKit, and the report half does: CanvasKit had no glyph
for `\t` (flutter/flutter#79153), fixed on Flutter master in September 2022.
This fork's floor is Flutter >= 3.10, and upstream only kept the issue open to
wait for stable — so that half needs no code.

The other half is "a tab reaching the text at all". Upstream's answer was to
replace tabs with spaces on load and on Tab keypress, and this fork has both.
So the question became: is there any path where a tab still gets in?

## Red — find the hole

Read the two conversion sites: `fullText` (code_controller.dart:447) and the
non-composing branch of `value=` (code_controller.dart:528-530). Then read the
composition branch (code_controller.dart:492-501) — it exists precisely to skip
editor transforms, and the conversion was one of those transforms.

Wrote the four controller tests. On `master`:

```
Expected: 'ab  '
  Actual: 'ab\t'
```

Two of four red. The load path and the Tab path were already right; the
composition path was not.

## Green — first attempt, and the break it caused

Moved the conversion into the composition branch, ahead of
`_updateCodeIfChanged`. Tests 3 and 4 went green, and the full suite went red:

```
RangeError (end): Invalid value: Not in inclusive range 0..3: 5
  text_editing_value.dart 174:17  TextEditingValueExtension.beforeSelection
  text_editing_value.dart 109:28  TextEditingValueExtension.tabsToSpaces
  code_controller.dart 499:29     CodeController.value=
```

The existing test "A transient out-of-range selection during composition is
applied without throwing" documents a real platform state: the composition
shrinks while the platform selection still points past the new end. The old
code never converted in that branch, so it never split the text there.
`tabsToSpaces` splits at `selection.start`/`end`, which threw.

Two things fell out of fixing it:

- the out-of-range selection has to be clamped to the text it points into — a
  selection past the end is transient, not meaningful;
- `tabsToSpaces` passed `composing` through unchanged. Converting a value
  whose composing region contains or precedes a tab therefore left the
  composing range at pre-conversion offsets —
  `Expected: TextRange(start: 15, end: 42) / Actual: TextRange(start: 14, end: 40)`.
  It now shifts past the tabs it precedes.

## Refactor — pin every branch

`tab_tofu_canvaskit_test.dart` keeps the four controller-level cases plus the
documented opt-out (no `TabModifier` ⇒ tabs are the consumer's business).
`tabs_to_spaces_test.dart` gains the three unit cases: out-of-range selection,
out-of-range composing range, and a composing range that spans tabs.

## Verification

```
flutter test                                            → 578 tests, all passed
dart format --output=none --set-exit-if-changed .       → no changes
dart analyze --fatal-infos lib test tool                → No issues found!
```

Fault injection, one source change at a time:

- revert `code_controller.dart` → tests 3 and 4 fail (`'ab\t'`);
- revert `text_editing_value.dart` → tests 6 and 8 fail (`RangeError`,
  and `TextRange(start: 14, end: 40)` instead of `start: 15, end: 42`).

Coverage: the gate is `--min 100`; every line added to `lib/` is reached by one
of the eight tests, including the clamp guard and both the early return and the
remap path of `_shiftedForTabs`.

One gate entry needed renumbering, not new proof: `EXEMPT_LINES` for
`text_editing_value.dart` keys the dead `throw AssertionError('')` in `select()`
by line number, and the new helper above it moved that throw from 188 to 229.
The proof in the comment is unchanged — `matchAsPrefix` cannot fail after
`indexOf` matched — so only the key moved. Exempted-line count stays 13.
