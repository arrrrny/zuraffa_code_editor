# TDD verification: codeline-copywith-drops-indent

## Commands

```bash
flutter test test/src/code/code_line_copy_with_indent_test.dart
flutter test                                   # full suite
dart analyze lib test
dart format --output=none lib test
```

## Results

| Step | Result |
|------|--------|
| RED (test file vs. unmodified master) | `00:00 +4 -2: Some tests failed.` — `Expected: 2` / `Actual: <0>` |
| GREEN (test file + fix) | `00:00 +6: All tests passed!` |
| Full suite (on master `8fc9fc6` + fix) | green |
| `dart analyze lib test` | `No issues found!` |
| `dart format --output=none lib test` | `Formatted 204 files (0 changed)` |

## Mutation sanity check

The fix is a single ternary branch, so the honest mutation check is: revert
`indent: indent` back to `indent: 0` and confirm tests 3 and 5 go red again.
Performed locally by `git checkout -- lib/src/code/code_line.dart` on a copy of
the fixed file — confirmed, 2 failures, `Actual: <0>`. The reverse mutation
(always `_calculateIndent(text)` with `text ?? this.text` already resolved) is
equivalent to the master behaviour, so no third case exists.

## Production-code diff

```
lib/src/code/code_line.dart | 2 +-
```

One line changed. No new files under `lib/`. No public API change.

## Coverage

New tests are the first coverage of `CodeLine.copyWith`. Bug fix, so the
coverage gate in `.github/workflows/dart.yaml` is **not** bumped by this PR
(the ratchet rule: the gate rises only in the PR that adds the tests behind a
higher number).
