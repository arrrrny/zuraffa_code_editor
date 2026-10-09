# Test report: codeline-copywith-drops-indent

- **File**: `test/src/code/code_line_copy_with_indent_test.dart` (new, 94 lines)
- **Tests**: 6
- **Framework**: `package:flutter_test` (`testWidgets` not needed — no widgets;
  `Code` is a plain model, `dart:ui` is imported for `TextRange`)

## Cases

### Group `CodeLine.copyWith`

1. **`replaces only the given fields, keeping the range as-is`**
   Builds a line with an explicit `TextRange(4, 8)` and copies it with a new
   `text`. Asserts `text` changed, `textRange` unchanged, `isReadOnly` still
   false. Passes on master (guards the non-regressed path).
2. **`recalculates the indent when text changes`**
   `_line('ab').copyWith(text: '    cd').indent == 4`, and the original line is
   untouched (`indent == 0`). Passes on master.
3. **`keeps the existing indent when text is not replaced`** — **RED on master**.
   `_line('  ab').copyWith(isReadOnly: true)` must keep `indent == 2`. Master
   returns 0.
4. **`replaces isReadOnly`**
   `_line('a').copyWith(isReadOnly: true).isReadOnly` is true. Passes on master.

### Group `Read-only sections keep their indentation`

5. **`a read-only line inside a named section keeps its indent`** — **RED on master.**
   The real-world regression. A Python `Code` with
   `BracketsStartEndNamedSectionParser()` and `readOnlySectionNames: {'locked'}`
   where `def locked():` sits at indent 4. Finds the read-only line containing
   `def locked():` and asserts `indent == 4`. Master returns 0 because
   `code.dart:200` calls `copyWith(isReadOnly: true)` without `text`.
6. **`a control: indentation of an unmarked code`**
   The same text with `readOnlySectionNames: {}` — the whole non-empty indentation
   ladder must survive (`[0, 4, 8]`). Passes on master and pins that the fix
   doesn't over-correct.

## Harness notes

- No `TestWidgetsFlutterBinding.ensureInitialized()` needed: nothing in this path
  schedules a post-frame callback.
- Plain `test()` (not `testWidgets`) so the controller's analysis debounce /
  history timers don't show up as pending-timer failures.
- `BracketsStartEndNamedSectionParser` is passed positionally as
  `namedSectionParser:` — matches the existing
  `test/src/code/code_named_sections_test.dart` style.

## Coverage

These 6 tests are the first coverage of `CodeLine.copyWith` (previously 0), and
they are the seed of the round-2 `test/src/code/code_line_test.dart` work.
