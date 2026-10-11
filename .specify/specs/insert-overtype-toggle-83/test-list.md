# Test List: Insert toggles insert/overtype mode

- **Slug**: insert-overtype-toggle
- **Issue**: 83
- **File**: `test/src/code_field/insert_overtype_test.dart`

Three surfaces: the toggle binding, the replacement transform, and the edits
that must keep inserting.

| # | Test | Status |
|---|---|---|
| 1 | Overtype is off by default | pass (was RED) |
| 2 | Pressing Insert once turns overtype on (real key) | pass (was RED) |
| 3 | Pressing Insert again returns to insert mode (real key) | pass (was RED) |
| 4 | Ctrl-Insert still copies instead of toggling overtype (real key) | pass |
| 5 | Insert does not toggle overtype while composing (real key) | pass |
| 6 | The setter and toggleOvertypeMode drive the same flag | pass (was RED) |
| 7 | Overtype replaces the character after the caret | pass (was RED) |
| 8 | Overtype inserts past the last character | pass (was RED) |
| 9 | Overtype replaces under a folded block | pass (was RED) |
| 10 | Overtype does not replace a selection | pass |
| 11 | An auto-paired keystroke keeps its pair under overtype | pass |
| 12 | A deletion is not an overtype | pass |
| 13 | An insertion away from the caret is not an overtype | pass |
| 14 | A read-only controller does not overtype | pass (was RED) |

Tests 1–3 and 6–9, 11 and 14 were red before the API existed — the file did not
compile against the old `CodeController`. Tests 2, 3 and 5 drive a real
`LogicalKeyboardKey.insert` through `createApp`, so they also fail on `lib/`
alone. Test 11 pins the interaction with the modifier dispatch by running the
same keystroke on a controller in insert mode and asserting both results are
identical, rather than hard-coding what auto-pairing produces.

Fault checks: reverting the `_overtypedValue` call reddens tests 7–9; reverting
the Insert binding reddens tests 2 and 3.

Test 1–5 need one extra `pump()` after `pumpController`: the focus request
`pumpController` makes is applied on the next frame, so a key sent immediately
after lands on an unfocused field and no shortcut map is consulted at all.
