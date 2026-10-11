# PR: ios-horizontal-scroll-85

- **Branch**: `bug/ios-horizontal-scroll-85` (from master `89ff2c6`)
- **Commit**: `c991901`
- **PR**: https://github.com/arrrrny/zuraffa_code_editor/pull/127
- **Title**: test(code): pin the code area's horizontal scroll on both of its paths (#85)
- **Base**: `master`
- **Body**: `pr-body.md`
- **Opened**: 2026-10-11
- **Closes**: #85 (upstream akvelon/flutter-code-editor#280)

## State

Opened. The body leads with the fact that the reported symptom does not
reproduce and the platform claim is inverted, so the review is not left to
guess why there is no code change: the drag split is Flutter's
(`text_selection.dart:3731`), the caret reveal already works, and the two
candidate fixes are spelled out with why each is rejected.

No `lib/` change — the reviewable surface is one new test file, the
specification artifacts, and the CHANGELOG entry.
