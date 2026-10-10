# TDD test list — #20 Tab tofu in CanvasKit

Status: **verification found a live gap; source change landed.**

| # | Test | Kind | State |
|---|------|------|-------|
| 1 | `Loading text with tabs converts them to spaces` | regression guard (already covered by `code_controller_tab_test.dart`) | green |
| 2 | `A tab arriving in a platform value update is converted` | regression guard | green |
| 3 | `A tab delivered by the platform while composing is converted` | **fault-detecting** | green |
| 4 | `A tab inside committed composing text is converted` | **fault-detecting** | green |
| 5 | `Without TabModifier the tabs are left to the consumer` | documents the opt-out | green |
| 6 | `tabsToSpaces: with a selection past the end of the text` | **fault-detecting** (`RangeError`) | green |
| 7 | `tabsToSpaces: with a composing range past the end of the text` | guard | green |
| 8 | `tabsToSpaces: with a composing range that spans tabs` | **fault-detecting** (stale offsets) | green |

Files: `test/src/code_field/tab_tofu_canvaskit_test.dart` (1-5),
`test/src/code_field/tabs_to_spaces_test.dart` (6-8).

## Red/green evidence

- **Red:** on `master` `df71234`, tests 3 and 4 fail with
  `Expected: 'ab  ' / Actual: 'ab\t'` — the composition branch never converted
  tabs.
- **Red, second round:** the first fix made tests 3 and 4 pass but broke the
  existing `code_controller_ime_composition_test.dart` test
  "A transient out-of-range selection during composition is applied without
  throwing" with
  `RangeError (end): Invalid value: Not in inclusive range 0..3: 5`. That is
  test 6's origin: the conversion had to tolerate a platform selection that
  points past its own text.
- **Green:** all 8 pass; `flutter test` 578 tests, all passed.

## Why the existing tests did not cover this

`code_controller_tab_test.dart` only drives the controller through the
constructor and through plain `value` assignments, which take the
non-composing path. `code_controller_ime_composition_test.dart` covers
composition but never a tab — a tab is not an IME character, so no existing
test produced one inside a composing region.
