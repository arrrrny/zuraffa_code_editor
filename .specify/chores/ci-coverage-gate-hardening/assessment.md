# Chore Assessment: CI pipeline hardening — coverage gate provenance and run hygiene

- **Slug**: ci-coverage-gate-hardening
- **Created**: 2026-10-10
- **Source**: the standing project goal — "implement proper CI for testing and
  most important[ly] 100% test coverage"
- **Verdict**: implement
- **Size**: small

## What the goal asks for

The pipeline must prove, on every push and every PR, that the package analyses
clean, is formatted, passes its tests, and is covered to 100%. It already does
all four — the audit below is about whether it does them *provably*, and
whether the numbers it prints can be trusted by the next reader.

## Finding: the gate is real, and it is the pipeline's strongest part

`.github/workflows/dart.yaml` runs, in order: `flutter pub get`, `flutter pub
outdated`, `dart analyze --fatal-infos`,
`dart format --output=none --set-exit-if-changed .`, `flutter test --coverage`,
then `python3 tool/coverage_gate.py --min 100`, and finally uploads to Codecov.

The gate is enforced for real, not decoration. Verified on the merge of PR #77
(CI run `38081200818`, 2026-10-10 19:47Z), whose log prints:

```
zuraffa_code_editor line coverage: 100.00% (3309/3309 lines over 105 files)
```

It also carries a ratchet: the step greps the gate's own `--min` argument out of
the base branch's copy of the workflow and fails a PR that lowers it, so the
number can only rise. `GITHUB_BASE_REF` is empty on push events, where there is
nothing to compare against.

## Gaps found, and what each one costs

1. **The gate's comment states a number that is no longer true.** It claimed
   "100.00% (3089/3089 lines)" for a measurement made on `master`; `master`
   now measures 3309, and the #35 branch measures 3327. A comment whose
   authority comes from being a measurement has to be re-measured when it
   changes, or the next reader cannot tell the stale number from the live one.
   Fixed: the comment now names the run it was measured in.

2. **Nothing names which lines a failure was about.** The gate prints a total.
   `coverage/lcov.info` is git-ignored and was thrown away at the end of the
   job, so a red run said "N lines uncovered" and nothing else — the reader had
   to re-run the suite locally to find them. Fixed: uploaded as an artifact with
   7-day retention.

3. **Every push to a branch re-ran the whole pipeline, including pushes that
   made earlier runs moot.** No `concurrency` group, so a rebase left two runs
   racing and the checks list could show a green run for a commit that was no
   longer the tip. Fixed: `cancel-in-progress` on a per-ref group.

4. **No job timeout.** A wedged `flutter test` would occupy a runner for the
   six-hour GitHub default instead of failing fast. Fixed: 30 minutes, which is
   ~6× the observed 2m50s.

5. **The default `GITHUB_TOKEN` permissions were broader than the job needs.**
   It reads the checkout and writes a status back. Fixed: `permissions:
   contents: read`.

6. **No manual re-run entry point.** `workflow_dispatch` added.

## What is deliberately not changed

- **The gate stays pinned at `--min 100`.** Raising it is not a thing; the
  ratchet keeps it honest in the other direction.
- **The helper-file generation stays inline in the workflow.** It is 6 lines,
  it must run *before* the tests, and a script would have to be kept in sync
  with the same logic. Extracting it would add a moving part to the one step
  nobody may edit casually.
- **Codecov stays.** It is the public number for the repo; the artifact is for
  debugging and does not replace it.
- **No new test runner, no parallel test sharding.** 56 s for 692 tests is
  not the problem this chore is for.

## Verification

- `python3 -c`/`ruby -ryaml`: the workflow parses; the job's step order is
  unchanged through `Coverage gate`, and the two new steps follow it.
- `dart format --output=none --set-exit-if-changed .` and
  `dart analyze --fatal-infos` on `master` at `c317bcb`: both clean (the change
  is YAML-only, so this only confirms the checkout is not disturbed).
- The pipeline itself must be watched on this PR: a green `Dart-CI-Pipeline`
  run is the acceptance criterion, since the concurrency, permissions,
  artifact and dispatch changes are only observable inside GitHub's runner.
