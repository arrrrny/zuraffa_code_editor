# TDD verification: paste-service-comments-cursor

## Commands

```bash
flutter test test/src/code_field/code_controller_paste_hidden_test.dart
flutter test                                   # full suite
dart analyze lib test
dart format --output=none lib test
```

## Results

| Step | Result |
|------|--------|
| RED (test file vs. unmodified master) | `00:00 +2 -1: Some tests failed.` — caret 60, expected 92 |
| GREEN (unified `cutSelection` rule) | caret test green, but `code_controller_folding_editing_test.dart` "…2nd identical folded block" **red** (expected `collapsed(13)`, got `(25, 26)`) — rejected |
| GREEN (narrowed `isCollapsed` rule) | `00:00 +3: All tests passed!` |
| Full suite (on master `8fc9fc6` + fix) | `00:00 +366: All tests passed!` |
| `dart analyze lib test` | `No issues found!` |
| `dart format --output=none lib test` | `Formatted 204 files (0 changed)` |

Test file: 91 lines, 3 tests, no production dependencies added.

## Mutation sanity check

Three mutations, each verified to break the right test:

| Mutation | Effect |
|---|---|
| delete the added `isCollapsed` arm | caret test RED (60) |
| drop `isCollapsed` from the condition | caret test green, "…2nd identical folded block" RED |
| revert to `replacedText` for the collapsed case | caret test RED (60) |

## Production-code diff

```
lib/src/code_field/code_controller.dart | 6 ++++-
```

One new branch (6 lines) inside an existing conditional. No new public API, no
new dependency, no change to `recoverSelection` / `cutSelection` /
`replacedText`.

## Coverage

New tests are the first direct coverage of the
`newValue.selection.isCollapsed && length >` path of `CodeController`'s `value`
setter. Bug fix, so the coverage gate is **not** bumped by this PR.
