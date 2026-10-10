# #26 — fix record

**Verified, then hardened on review.** The reported crash does not reproduce
on this fork; the tests ship as the deliverable, and the review round applied
the same `currentContext` guard `rebuild()` carries to the `initState`
callback — see "Review follow-up" below.

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
the last of four), and dropping a tab while another is on screen with its
autocomplete popup open. Each asserts `takeException()` stays null. They exist
so that a future change to the popup positioning path fails a test rather
than a user's app.

## Review follow-up: the unguarded read is gone

The first revision left `code_field.dart:312-313` unguarded, recorded under
"the 100 % line-coverage gate". The automated review corrected that record:
the gate (`tool/coverage_gate.py`) measures **line** coverage and exempts
whole files (`EXEMPT_FILES`) and individual provably-dead lines
(`EXEMPT_LINES`) — there is no branch-proof mechanism — and the guard's added
lines all execute on the non-null path the tests already take. The callback
now carries the same `currentContext` guard as `rebuild()`, so the named site
is guarded like its twin and the report's crash shape is closed off rather
than merely unobserved in the containers tried here.
