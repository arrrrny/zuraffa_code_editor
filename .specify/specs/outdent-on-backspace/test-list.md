# Test List: Outdent on Backspace

- **Slug**: outdent-on-backspace
- **Issue**: 21
- **File**: `test/src/code_modifiers/outdent_modifier_test.dart`

Two surfaces to pin: the deletion dispatch itself, which did not exist, and the
`OutdentModifier` that ships on top of it.

| # | Test | Status |
|---|---|---|
| 1 | the deletion dispatch consults a modifier registered for the deleted character | pass (was RED) |
| 2 | the deletion dispatch lets the modifier rewrite the value, not just observe it | pass (was RED) |
| 3 | the deletion dispatch reports the parameters an insertion modifier would see | pass (was RED) |
| 4 | the deletion dispatch does not consult a modifier registered only for insertions | pass (was RED) |
| 5 | the deletion dispatch does not consult it when the text did not shrink by one | pass (was RED) |
| 6 | OutdentModifier removes one indent level from the leading whitespace | pass (was RED) |
| 7 | OutdentModifier removes one indent level from the middle of the indent | pass (was RED) |
| 8 | OutdentModifier removes only the spaces that are there, not a full tab | pass (was RED) |
| 9 | OutdentModifier honours a tabSpaces other than four | pass (was RED) |
| 10 | OutdentModifier leaves a backspace in the code alone | pass (was RED) |
| 11 | OutdentModifier is part of the default modifiers | pass (was RED) |
| 12 | OutdentModifier does not fire for a disabled modifier set | pass (was RED) |
| 13 | a read-only controller refuses the outdent (real key) | pass (was RED) |
| 14 | a real Backspace key outdents the editor (real key) | pass (was RED) |
| 15 | a real Backspace outside the indent deletes one char (real key) | pass (was RED) |
| 16 | a real Backspace outdents below a folded block (real key) | pass (added after review) |

Tests 1–5 are red before `CodeModifier.deletesChar`, `_deletionModifierMap` and
`_deletedLoc` exist: the test file does not compile against the old base class.
Tests 6–12 are red because `OutdentModifier` does not exist. Tests 13–16 drive a
real `LogicalKeyboardKey.backspace` through `createApp`, so they would also fail
on `lib/` alone. Test 16 pins the folded-block half of acceptance criterion 7,
which the review found asserted in the docs but never pinned.
