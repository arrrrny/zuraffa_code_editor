# PR: markup-folding-103

- **PR**: https://github.com/arrrrny/zuraffa_code_editor/pull/129
- **Issue**: https://github.com/arrrrny/zuraffa_code_editor/issues/103
  (upstream `akvelon/flutter-code-editor#311`)
- **Branch**: `bug/markup-folding-103`
- **Base**: `master`
- **Commit**: `0ea7ac8` — `fix(folding): give XML documents foldable markup blocks (#103)`
- **Body**: `pr-body.md`
- **State at open**: OPEN, awaiting pool review

## Verification attached

- `flutter test` — 765/765
- `dart analyze` — clean; `dart format` — clean
- Coverage gate — 100.00% (3374/3374 over 106 files), no new exemption
- Behavioural red check — `Actual: []` on the `CodeController` case without the
  factory dispatch

## Notes for the reviewer

- The filed `Where it lives` (`lib/src/highlight/`) is a red herring: the
  highlighting half of the report was measured and does not reproduce. The
  evidence is in `assessment.md` so the absence of a highlight-layer change is
  not a gap.
- `serviceCommentsSources` is accepted but never consulted — comments are not
  markup blocks by design, and `<!-- -->` produces no block.
- No exhaustive switch over `FoldableBlockType` exists in `lib/` or `test/`, so
  adding `markup` is additive.
