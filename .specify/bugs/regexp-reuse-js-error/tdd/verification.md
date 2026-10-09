# Verification Report: Reusing a RegExp causes a JavaScript error on web

- **Slug**: regexp-reuse-js-error
- **Issue**: 24
- **Verdict**: PASS_WITH_GAPS

## Evidence

- RED (no seam) → GREEN (seam) observed directly.
- Mutation: wrong pattern fails the contract test.
- `dart analyze --fatal-infos`: 0 issues. `dart format`: clean.
- Full suite: all tests pass.

## Gaps

- The original defect is dart2js-only and could not be reproduced on the VM;
  the "shared instance" mutation is invisible there because Dart caches
  `RegExp` objects by pattern. Web verification would require a dart2js /
  Chrome run, which the repo's CI does not currently do.
