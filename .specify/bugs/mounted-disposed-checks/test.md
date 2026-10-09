# Bug Verification: Guarded lifecycle continuations (mounted-disposed-checks)

- **Slug**: mounted-disposed-checks
- **Tested**: 2026-10-09
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial
- **TDD verification**: ./tdd/verification.md (verdict PASS_WITH_GAPS)

## Summary

The reproducible symptom is gone: disposing the gutter error-icon popup during
the 50 ms close delay no longer throws `setState() called after dispose()`, and
that behavior is pinned by a test that fails when the guard is removed
(mutation-checked). The second site in the assessment
(`CodeSearchController._onEnterKeyPressed`) could not be reproduced as a crash
on the test toolchain — on Flutter 3.47.5 `FocusNode.requestFocus` on a
detached node is a silent no-op — so its fix is hardening rather than a
verified crash repair, and no test on this toolchain can detect the guard's
removal.

## Checks Performed

| Check | Command / Action | Result | Notes |
|---|---|---|---|
| Reproduction, symptom 1 (post-fix) | `flutter test test/src/gutter/error_popup_dispose_test.dart` | pass | Unmount inside the 50 ms window + pump 60 ms; pre-fix this threw `setState() called after dispose()` |
| Reproduction, symptom 1 (guard removed) | `git stash push lib/src/gutter/error.dart` + same test | fail | RED re-proved, then restored |
| Reproduction, symptom 2 (post-fix) | `flutter test test/src/search/search_enter_dispose_test.dart` | pass | Dispose inside the `Future.delayed(Duration.zero)` gap; never threw, even pre-fix |
| Reproduction, symptom 2 (guard removed) | guard deleted from `lib/src/search/controller.dart` + same test | pass | Mutation not detected — toolchain no-op, see residual risks |
| New tests | both new test files | pass | 4 tests (2 dispose cases + 2 happy paths) |
| Regression suite | `flutter test` | pass | 299/299 green (295 pre-existing + 4 new) |
| Lint / type-check | `dart analyze --fatal-infos` | pass | 24 info-level issues, all pre-existing on master; zero new |

## Output Excerpts

```
$ flutter test
00:29 +299: All tests passed!

$ # removing the mounted guard from lib/src/gutter/error.dart
The following assertion was thrown running a test:
setState() called after dispose(): _GutterErrorWidgetState
Failing tests:
  test/src/gutter/error_popup_dispose_test.dart: Disposing during the 50ms popup-close delay does not throw

$ # removing the _disposed guard from lib/src/search/controller.dart
00:03 +2: All tests passed!      <-- mutation NOT detected on Flutter 3.47.5
```

## Residual Risks

- **Symptom 2 is unverified by construction.** The upstream report ("focus
  request on a disposed node throws") does not reproduce on Flutter 3.47.5, so
  the `_disposed` guard is prevention, not repair. If the pool/CI later runs
  the suite on an older supported Flutter, the test may surface the original
  crash there — that is the point of keeping it.
- The gutter guard changes behavior only in the dispose window; no visual or
  timing change for the happy path (covered by the popup-close test).
- `dart analyze --fatal-infos` still reports 24 info-level issues on this
  branch; they are identical to master's set and are scheduled for the
  CI-alignment work, not for this fix.

## Recommendation

Merge PR #8 and close the bug for the reproducible symptom, with the second site
recorded as hardened-not-proven. Re-run this verification against the minimum
supported Flutter once the dependency floor in #7 lands; if the crash does
reproduce there, the existing tests will fail and this file should be updated
from `partial` to `verified`.
