# TDD cycle log: codeline-copywith-drops-indent

Date: 2026-10-10 · Branch: `bug/codeline-copywith-drops-indent` (based on
`origin/master` @ `8fc9fc6`)

## RED

Wrote `test/src/code/code_line_copy_with_indent_test.dart` (6 tests) **before**
touching `lib/src/code/code_line.dart`, then ran it against unmodified master:

```
Failing tests:
  code_line_copy_with_indent_test.dart: CodeLine.copyWith keeps the existing indent when text is not replaced
  code_line_copy_with_indent_test.dart: Read-only sections keep their indentation a read-only line inside a named section keeps its indent

    Expected: 2
    Actual: <0>
```

4 passed, 2 failed. The two failures are exactly the "field not passed is
silently reset" symptom.

## GREEN

Applied the one-line fix in `lib/src/code/code_line.dart:40`:

```diff
-        indent: text == null ? 0 : _calculateIndent(text),
+        indent: text == null ? indent : _calculateIndent(text),
```

```
00:00 +6: All tests passed!
```

## REFACTOR

No refactor required. Considered and rejected (recorded in `fix.md`):

- adding an `indent` parameter to `copyWith` (widens API, doesn't fix the
  call sites);
- recalculating from `this.text` when `text == null` (wasteful, diverges from a
  hand-set indent);
- routing `copyWith` through the two `fromTextAnd*` factories (churn, no gain).

Also deliberately **not** fixed here (out of scope, noted in `assessment.md`):
`operator ==`, `hashCode`, and `toString` all omit `indent`.

## Full-suite + static checks

- `flutter test` — full suite green on top of master `8fc9fc6`.
- `dart analyze lib test` — `No issues found!`
- `dart format --output=none lib test` — clean (`Formatted 204 files (0 changed)`).
