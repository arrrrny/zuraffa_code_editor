# Stack Profile

Detected: 2026-10-09
Engine: raw (non-zuraffa) — `zfa` is installed (v7.0.0) but the repo has no
`.zfa.json`, so it is not zuraffa-wired; raw flutter commands are the engine.

## Commands (proven)

- single_test: `flutter test <path/to/test.dart>`
- full_suite: `flutter test`
- build: `dart analyze --fatal-infos` && `dart format --output=none --set-exit-if-changed .`
- loop: `flutter test <path>` in a red → edit → green loop (no external loop engine)
- verify: `flutter test` (+ `flutter test --coverage` for the coverage drive)

## Notes

- 295 tests, all green on master at detection time.
- Pre-existing (master) red flags: 2 files with `dart format` drift
  (`lib/src/code/code.dart`, `test/src/folding/folded_closing_line_test.dart`)
  and 24 info-level analyze lints. Owned by the CI-alignment chore, not TDD work.
- Local Flutter is 3.47.5; CI pins 3.19.6. Newer-SDK surfacing (e.g.
  `non_exhaustive_switch_statement`) must stay fixed locally to keep the local
  gate green.
