# Quickstart: highlight-cursor-line

Everything needed to verify this spec, in the order it should be run.

## 1. Worktree and branch

```bash
cd /Users/arrrrny/Developer/zuraffa_113
git log --oneline -1          # must be the plan commit; tree clean
flutter pub get
```

`--concurrency=2` on **every** `flutter test` invocation (and `-j 2` for
`dart test`). `flutter test` ignores `dart_test.yaml` entirely, so the flag is the
only lever — and it must be passed every time. Never raise it on this host.

## 2. Run the regression net first

Before writing anything new, prove #86 still passes. These eleven tests are the
contract this spec must not break:

```bash
flutter test --concurrency=2 test/src/code_field/per_line_background_test.dart
```

They must pass **unmodified**. If any goes RED after a change to the layer or the
gate, the composition is wrong — do not edit the test.

## 3. The CI-identical coverage gate

The repo's real gate, byte-for-byte what the pool's CI runs. The helper imports
every file under `lib/` except the `*_web.dart` ones, so coverage is measured
against the whole library rather than the touched module:

```bash
# generate test/coverage_helper_test.dart (one import per lib/**/*.dart except *_web.dart)
flutter test --coverage --concurrency=2
python3 tool/coverage_gate.py --min 100
rm test/coverage_helper_test.dart && rm -rf coverage/
```

Must read `Coverage gate: 100.00% >= 100.00% — OK`. Anything below 100% is a
blocker, not a note.

Two traps:

- **`flutter test` hides failures.** A red bar with no failure text means grep the
  log: `EXCEPTION CAUGHT`, `Expected:`, `Actual:`.
- **A gate run must reflect the final committed tree.** Adding a test file
  mid-run invalidates the number — stop, commit, restart.

`EXEMPT_LINES` in `tool/coverage_gate.py` pins by **line number**, so any
insertion above an exempted line shifts it. Renumber after every insertion, and
add an exemption only with a written reason proving the branch is dead.

## 4. Static gates

```bash
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
```

Note: `analysis_options.yaml` excludes `lib/src/wip` from analysis. Nothing this
spec touches is under `lib/src/wip`, but if a change strays there, say so in the
PR — new `wip` code is unlinted and the reviewer should not have to discover it.

## 5. What must fail before the implementation exists

Per the repo's TDD profile, every test below is written and run RED first. This
is the checklist that proves the tests can actually fail:

| Change | Test that must go RED |
|---|---|
| Remove the `??` composition | The caret-line test — the tint disappears |
| Remove the caret-index guard | The no-selection and end-of-text tests throw `RangeError` instead of rendering |
| Use `selection.baseOffset` instead of `extentOffset` | The shift-arrow test highlights the anchor line, not the caret's |
| Revert the gate to `!= null` only | The "no hooks at all keeps its tree" test finds a `Stack` where there should be none |
| Hard-code the caret line to `0` | Every caret-move test except the first |
| Delete the corrected doc example's assertion | Coverage of the documented path drops |

The single most likely wrong implementation — computing the caret line per row
from `selection.base`, with no guard — passes the "caret is on line 2" test and
fails only under a selection, a `-1` sentinel, and an end-of-text caret. Those
three tests are therefore the load-bearing ones.

## 6. Known host flake

`test/src/code_field/no_language_keystroke_test.dart` asserts an absolute 100 ms
bound calibrated on a machine where the with-language parse measures 80.7–96. ms.
On this host that parse measures ~570 ms, so the test fails under full-suite load
**on master too** — it is environmental, not a regression. Re-run it alone to
confirm:

```bash
flutter test --concurrency=2 test/src/code_field/no_language_keystroke_test.dart
```

Do not widen the bound: it is a tripwire for a real regression, and loosening it
weakens it silently. Flag it in the PR body with the master comparison numbers.

## 7. PR

Only after the gate reads 100.00% and both static gates are silent. The PR body
records: what the field is, the `extent`-not-`base` decision and why, the guard
and the three caret states it covers, the corrected doc example, and the
coverage number. Then push and requeue the pool — the pool merges, we do not.
