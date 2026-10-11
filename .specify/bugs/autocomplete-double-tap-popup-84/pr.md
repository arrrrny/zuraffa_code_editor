# Bug Fix PR: a single tap commits, and the popup fits the window

- **Slug**: autocomplete-double-tap-popup-84
- **Opened**: 2026-10-11
- **PR**: 126
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/pull/126
- **Branch**: bug/autocomplete-double-tap-popup-84
- **Issue**: 84

The popup's tap commit moves from `onDoubleTap` to `onTap`, and the popup is
clamped into the real window (`MediaQuery`) instead of the editor's own render
box, with the vertical flip decided on the height the rows actually need.
