# Test: gutter-overflows-narrow-field

## Full suite

`flutter test --concurrency=2 --coverage` on
`bug/gutter-overflows-narrow-width-259`:

```
02:19 +973: .../js_workarounds_test.dart: Web workarounds disabling the built-in search is a no-op off the web
02:20 +974: All tests passed!
```

**974 tests, 0 failures** (967 on `105d298` plus the 7 new ones).

## New tests

`test/src/gutter/gutter_overflows_narrow_field_test.dart` (7 tests):

| Test | Result |
|---|---|
| `a field narrower than the gutter keeps the gutter inside it` | green (red without the fix) |
| `the numbers still render, inside the field` | green (red without the fix) |
| `no width in the range overflows the row` | green (red without the fix) |
| `the code area keeps every pixel the gutter is not using` | green (regression guard — green on master) |
| `a field that can hold the gutter gets the width it asked for` | green (regression guard — green on master) |
| `an oversized gutter is capped, not honoured past the field` | green (red without the fix) |
| `an unbounded field is left exactly as it was` | green (regression guard — green on master) |

## Red check

`git stash push lib/src/code_field/code_field.dart`, then
`flutter test --concurrency=2 test/src/gutter/gutter_overflows_narrow_field_test.dart`:

```
00:05 +3 -4: Some tests failed.
```

`A RenderFlex overflowed by 28 / 44 / 148 pixels on the right` — four of the
seven fail, and the three that pass are exactly the regression guards.

## Regression suites

The three suites that the abandoned `Flexible` attempt reddened, and which
must stay green under the shipped bound:

```
horizontal_scrollbar_placement_test.dart
line_numbers_follow_scroll_test.dart
current_line_highlight_test.dart
→ All tests passed (26)
```

## Coverage

`python3 tool/coverage_gate.py --min 100` over the CI-faithful helper:

```
zuraffa_code_editor line coverage: 100.00% (3627/3627 lines over 110 files)
Coverage gate: 100.00% >= 100.00% — OK
```

3624 lines on `105d298`, 3627 with this fix's three new lines of branch and
comments — the fix adds no uncovered line, and the ratchet does not move.
