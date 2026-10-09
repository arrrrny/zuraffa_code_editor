# Verification Report: RenderBox was not laid out when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Issue**: 32
- **Verdict**: PASS_WITH_GAPS

## Evidence

- RED (guard reverted via `git stash`) → GREEN (guard present) observed directly;
  the RED message is the `hasSize` assertion upstream #275 reports.
- Mutation: the change under test *is* the mutation — `git stash` of
  `lib/src/code_field/code_field.dart` restores the failure, so the new tests
  are load-bearing.
- `dart analyze --fatal-infos`: 0 issues. `dart format --output=none lib test`:
  clean.
- Full suite: 352 tests pass.
- Coverage gate (`python3 tool/coverage_gate.py --min <gate>`), measured the way
  CI measures it (CI helper imports every `lib/**` file, fresh `coverage/` dir):
  see the PR description for the number.

## Gaps

- The report's literal repro (a plain `CodeController` + `CodeField`, nothing
  else) does not fail on current master, so the test pins the unguarded path
  from the report's own stack trace under a synthetic layout-phase notification
  instead. See `test.md` → "Honest caveat".
- `GutterWidget`'s mid-frame `setState` still asserts when the gutter is in the
  tree. The test pumps the field with `GutterStyle.none` to stay out of that
  path; the gutter defect is not fixed here and is recorded as out of scope.
- `_updatePopupOffset`'s early return is exercised but not independently
  observable (the autocomplete popup is off by default).
- No web/dart2js run in CI; the `hasSize` assertion is engine- and
  platform-independent, so this is recorded but not verified on web.
