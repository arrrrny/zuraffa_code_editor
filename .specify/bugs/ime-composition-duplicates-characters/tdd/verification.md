# Verification Report: IME composition duplicates/drops characters

- **Slug**: ime-composition-duplicates-characters
- **Issue**: 11
- **Verdict**: PASS

## Evidence

- RED → GREEN observed directly: every defect from the assessment failed its
  test before the fix and passes after (exact failures quoted in test.md).
- Full suite: `flutter test` → 314 tests pass.
- `flutter analyze --no-fatal-infos` → 0 issues; `dart format` → clean.
- Coverage measured CI-identically (fresh `coverage/` + generated
  `test/coverage_helper_test.dart`): 90.66% (2690/2967), coverage gate
  (`--min 88.0`) OK. The fix adds no uncovered lines.
- Regression pin: the diff-based Latin path is untouched; the 313 pre-existing
  tests still pass unchanged.

## Mutation checks

- Controller `onEnterKeyAction` guard removed → test 6 fails.
- Widget composing gate removed alone → no failure (double protection);
  removed together with the controller guard → test 9 fails.
- Pre-fix state (whole fix reverted) → 8 of 10 new tests fail, including the
  core commit-drop defect.

## Gaps

- Windows/web engine behavior (the reported duplicate/two-char artifacts) is
  not reproducible in the VM test environment; the pinned invariants are the
  controller-side preconditions that break the engine desync and the commit
  corruption.
