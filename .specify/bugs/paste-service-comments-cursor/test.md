# Test report: paste-service-comments-cursor

- **File**: `test/src/code_field/code_controller_paste_hidden_test.dart` (new, 91 lines)
- **Tests**: 3
- **Framework**: `package:flutter_test`, plain `test()` (no widgets — `CodeController`
  is a pure model; `flutter/services.dart` supplies `TextEditingValue` /
  `TextSelection`)

## Cases

1. **`caret lands at the end of the pasted run`** — **RED on master.**
   Builds the report's exact scenario: text `'// [START section2]\nvoid method() {\n}\n'`
   with `BracketsStartEndNamedSectionParser`, then delivers what the framework
   delivers on paste — the 19-char visible text plus the pasted block, caret at
   the end of the inserted run (164).
   Asserts: the resulting visible text is shorter than the pasted run (sanity —
   the service comments really did become hidden ranges), and the caret is at
   `controller.value.text.length`.
   Master: caret **60**, expected **92**.

2. **`caret lands after the pasted run when it is inserted mid-text`** — guards
   the case with **no** newly hidden ranges: `'int i = 1;\n'` inserted at
   offset 1 of `'void method() {\n}\n'`. Asserts the text (the leading `v` was
   displaced by the paste) and the caret at 11. Passes on master — it proves the
   fix doesn't regress ordinary mid-text insertion.

3. **`the pasted text reaches fullText in full`** — guards that the paste is not
   truncated and only tabs are rewritten: `fullText` ends with
   `'  }// [END section4]\n}\n'` and is 183 chars. Passes on master.

## Harness notes

- `_paste(controller, inserted)` is the whole point: it rebuilds the **visible**
  text with the inserted run and puts the caret at the end of the run. That is
  what the framework does; testing any other way does not reproduce the bug.
- `TwoMethodsSnippet.mode` (Java) matches the report's "Use Java" and the
  existing `code_controller_hidden_ranges_test.dart` harness.
- Tabs in the pasted literal are literal `\t`: the editor rewrites them to
  spaces on paste, which is why test 3 asserts on the tail rather than the
  whole pasted string.
- No `TestWidgetsFlutterBinding.ensureInitialized()`: nothing here schedules a
  post-frame callback.

## Coverage

These tests cover the `newValue.selection.isCollapsed` + `length >` path of
`CodeController`'s `value` setter, which had **no** direct coverage before.
