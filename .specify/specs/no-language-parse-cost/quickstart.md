# Quickstart — validating the no-language keystroke pin (#111)

The deliverable is a measurement, not a behaviour change. This guide is how a
reviewer re-derives the numbers and confirms the pin holds.

## Prerequisites

- Flutter 3.47.5 (`flutter --version`)
- Dependencies resolved (`flutter pub get`)

## Run the pin

```bash
flutter test test/src/code_field/no_language_keystroke_test.dart --reporter expanded
```

Expected: green, with the measured pairs printed:

```text
no-language keystroke pin: 4800 lines
  highlight.parse  no language: 3000us
  highlight.parse  java:        318200us
  keystroke median  no language: 43000us
  keystroke median  java:        378000us
```

## What the assertions check

| Assertion | Traces to |
|---|---|
| no-language parse < 5% of with-language parse | SC-001, FR-004 |
| no-language keystroke median < 100 ms | SC-002, FR-002 |
| no-language keystroke ≤ with-language keystroke | SC-003 |
| no-language keystroke median / with-language keystroke median is bounded, so making the parse expensive reddens the suite | SC-004, FR-004, FR-005 |

The bounds are ratios between two measurements taken on the same document in
the same test body, deliberately not absolute millisecond budgets — see
`research.md` Decision 2 for why absolute budgets are flaky on shared CI.

## Reproduce the manual measurement

The numbers can be re-derived without the test by running a throwaway probe
that constructs a `CodeController` with no language and drives one edit. Two
probes were used before this spec was written (`test/tmp_probe_111_test.dart`,
`test/tmp_probe_111b_test.dart`); both were deleted and neither was committed.
A new probe goes in `test/` and is deleted before any commit, per the repo
convention — `dart format` flags stray scratch files.

## Confirm no code change is needed

```bash
git diff master --stat -- lib/
```

Expected: empty. The feature ships only the test that pins the measurement.

## Confirm the coverage gate still passes

```bash
rm -rf coverage
file=test/coverage_helper_test.dart
echo "// Helper file to make coverage work for all dart files" > $file
echo "// ignore_for_file: unused_import, directives_ordering" >> $file
find lib ! -name '*_web.dart' -name '*dart' | cut -c4- | \
  awk -v package= '{printf "import '\''package:zuraffa_code_editor%s%s'\'';\n", package, $1}' >> $file
echo "void main(){}" >> $file
flutter test --coverage
git checkout -- example/
python3 tool/coverage_gate.py --min 100
rm -f test/coverage_helper_test.dart && rm -rf coverage
```

Expected: `PASS` at 100%. The new test only exercises existing `lib/` lines,
so it cannot lower the number.
