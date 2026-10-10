# Spec PR: Outdent on Backspace

- **Slug**: outdent-on-backspace
- **Opened**: 2026-10-10
- **PR**: 74
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/pull/74
- **Branch**: spec/outdent-on-backspace
- **Issue**: 21

Opens the deletion half of the `CodeModifier` dispatch (`deletesChar` +
`_deletionModifierMap` + `_deletedLoc`) and ships `OutdentModifier` on top of it,
registered by default. 15 new tests; 625 total, all green; coverage gate 100%.
