# Test report: fold-unfold-deselects-106

- **Branch**: `bug/fold-unfold-deselects-106`
- **Base**: `master` @ `1b8634f` (PR #130 merge)
- **Date**: 2026-10-11

## Commands

| Command | Result |
|---|---|
| `flutter test` | 776/776 passed |
| `flutter test --coverage` + `tool/coverage_gate.py --min 100` | 100.00% (3389/3389 lines over 106 files) |
| `dart analyze --fatal-infos` | no issues |
| `dart format --output=none --set-exit-if-changed .` | clean |
| `./scripts/local_ci.sh` (`.github/workflows/dart.yaml`, `GITHUB_BASE_REF=master`) | 9 steps ran, 0 failed |

## Coverage delta

`lib/src/code_field/code_controller.dart` +37 lines, `test/src/code_field/
fold_unfold_keeps_selection_test.dart` new (7 tests). Every new line is
covered: the remember branch, the forget branch, the `value`-setter clear and
the `applyHistoryRecord` clear are each reached by a named test. No change to
`EXEMPT_FILES` or `EXEMPT_LINES` — the gate stays pinned at 100%.

## Fault detection

Reverting only the assignment of `_selectionHiddenByFold` in
`_getValueWithCode`:

| Test | before revert | after revert |
|---|---|---|
| a selection inside the folded block survives the round trip | green | red — `Expected: <24> Actual: <42>` |
| a caret inside the folded block survives the round trip | green | red — `Expected: <47> Actual: <42>` |
| a selection straddling the fold survives the round trip | green | red — `Expected: <TextSelection(baseOffset: 0, extentOffset: 44, ...)> Actual: <TextSelection(baseOffset: 0, extentOffset: 42, ...)>` |
| a selection outside the folded block is not resurrected | green | green (regression pin) |
| moving the selection after the fold forgets the folded one | green | green (regression pin) |
| unfolding another block does not resurrect the folded selection | green | green (regression pin) |
| the remembered selection does not leak into a plain keystroke | green | red — `Expected: <44> Actual: <47>` |

## Known-flaky neighbour

`test/src/code_field/no_language_keystroke_test.dart` ("No language selected
does not make a keystroke expensive") is a wall-clock ratio pin. It passes in
isolation (66 ms median against a 100 ms bound) and passed in this run, but
has failed twice before under full-suite load with the same suite otherwise
green. Pre-existing, untouched by this change, and out of scope for this PR.
