# #26 — fix record

**No code change was made.** The fix for this report already exists on this
fork, ahead of the point where the reporter ran into it.

## What the report blames

`lib/src/code_field/code_field.dart:308-315`, the post-frame callback in
`initState`, which reads `_codeFieldKey.currentContext!.size!` — two
null-check operators on a context that can be gone by the time the callback
runs, and on a size that can be unset before a layout.

## What this fork has at the same call sites

- `rebuild()` (`code_field.dart:368-384`) does the identical job, guarded,
  with a comment recording the observation that motivated the guard:
  `_codeFieldKey.currentContext` was seen null in tests.
- `_onTextChanged` and `_updatePopupOffset` gate on
  `_isEditorBoxLaidOut` before reading the box.
- `scrollOffsetOrZero` (`code_field.dart:233-238`, added for upstream #275)
  closes the sibling failure mode where a scroll notification lands before the
  scroll view has a position.

## Why it doesn't reproduce

The container that triggers the crash upstream has to keep several
`CodeField`s alive with the same `GlobalKey`-driven timing window. `TabBarView`
builds only the tab that is on screen — the widget-tree probe counted one
`CodeField` alive at a time, and one after every tab switch — so the field whose
`initState` callback runs has always been laid out. The same held for
`IndexedStack` with an inactive index, an `Offstage` sibling, and two
`CodeField`s in a `Column`.

## What ships instead

`test/src/code_field/tabbarview_multiple_codefields_test.dart` — three guard
tests: switching tabs forward and back, a never-shown tab (`initialIndex` on
the last of four), and dropping a tab while another is on screen. Each asserts
`takeException()` stays null. They exist so that a future change to the popup
positioning path fails a test rather than a user's app.

## Deliberately left alone

`code_field.dart:312-313` keeps the unguarded `!`s. Hardening them needs a
reachable null state to test, and no container tried produces one. Under this
repo's 100 % line-coverage gate, untested guard branches would have to be
exempted with a proof comment that asserts unreachability — the opposite of
what the reviewer would want to see. Recorded as an open item in `spec.md`.
