# PR: java-hash-strings-104

- **PR**: https://github.com/arrrrny/zuraffa_code_editor/pull/130
- **Issue**: https://github.com/arrrrny/zuraffa_code_editor/issues/104
  (upstream `akvelon/flutter-code-editor#42`)
- **Branch**: `bug/java-hash-strings-104`
- **Base**: `master`
- **Commit**: `668c8fd` — `fix(java): a # and triple-quoted strings no longer
  cost a file its highlighting (#104)`
- **Body**: `pr-body.md`
- **State at open**: OPEN, awaiting pool review

## Verification attached

- `flutter test` — 766/766
- `dart analyze` — clean; `dart format` — clean
- Coverage gate — 100.00% (3371/3371 over 106 files), no new exemption
- Behavioural red check — `Actual: []` with only the registration line reverted

## Notes for the reviewer

- The repair is a **copy** of the `java` mode, not the shipped mode with
  `illegal` cleared, and the reason is the compile cache in `Mode`, not style:
  a cleared field is only effective before the first parse. Proof that the
  ordering does not matter for the copy is the passing suite.
- `Mode` has no `operator==`, so `modeToRegister`'s identity check is exact,
  and a caller's own hand-built mode is returned untouched.
- A raw newline inside an ordinary `"..."` still bails. Deliberate, and argued
  in `assessment.md` under Non-goals.
- The one harness artifact in `test.md` (a perf pin failing only under a
  full-suite coverage run, 115 ms against a 100 ms bound, and 58.5 ms when the
  same file is measured in isolation) is pre-existing and unrelated: the
  ratio assertions in that file, which are the ones that detect a path-specific
  change, are green at 0.101 against a 0.6 bound.
