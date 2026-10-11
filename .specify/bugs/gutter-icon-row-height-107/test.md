# Test: gutter-icon-row-height-107

## Full suite

`flutter test` on `bug/gutter-icon-row-height-107` @ `d12d537`:

```
00:55 +757: .../horizontal_scroll_behaviour_test.dart: ...
00:55 +758: All tests passed!
```

**758 tests, 0 failures.**

## New tests

`test/src/gutter/gutter_icon_row_height_test.dart` (4 tests):

| Test | Result |
|---|---|
| `13px line box: gutter rows stay one code line tall` | green (red without the fix) |
| `sub-16 font sizes: gutter rows stay one code line tall` | green (red without the fix) |
| `every visible glyph is clamped to the code line height` | green (red without the fix) |
| `icons stay at 16 above a 16px line box` | green (characterisation — green on both trees) |

## Red check

`git stash push lib/src/gutter/gutter.dart lib/src/gutter/fold_toggle.dart`, then:

```
13px line box: gutter rows stay one code line tall [E]
  Expected: a numeric value within <0.001> of <30.5>
  Actual: <32.0>

sub-16 font sizes: gutter rows stay one code line tall [E]
  Expected: a numeric value within <0.001> of <28.5>
  Actual: <32.0>
  fontSize 9.0: gutter row 1 is off the code grid (line height 9.0)

every visible glyph is clamped to the code line height [E]
  Expected: a value less than or equal to <13.0>
  Actual: <16.0>

icons stay at 16 above a 16px line box  <- GREEN
```

`32.0` is the pitch of two stacked 16px glyph boxes — the row was being sized
by the icon column, not the code line.

## Static checks

- `dart analyze` — `No issues found!`
- `dart format --output=none --set-exit-if-changed lib test` — clean

## Coverage gate

```
zuraffa_code_editor line coverage: 100.00% (3371/3371 lines over 105 files)
Coverage gate: 100.00% >= 100.00% — OK
```

The clamp and the fallback branch in `_rowHeight()` are both covered by the new
tests; the gutter always passes `iconSize` explicitly, so `FoldToggle`'s
`_defaultIconSize` default value is never exercised — it exists only so a direct
mount of the widget keeps today's 16px rendering.

One `tool/coverage_gate.py` exemption line number moved: the dead
`unfoldAt` lambda in `_fillFoldToggles`' first loop was exempted at
`gutter.dart:230` and is now at `:260`, because the `_iconSize`/`_rowHeight`
helpers were inserted above it. The reason is unchanged — the second loop
overwrites that toggle before it can be tapped.
