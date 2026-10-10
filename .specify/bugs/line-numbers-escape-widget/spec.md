# #19 — Line numbers escape the widget and never scroll

- **Status:** verified already fixed on this fork; regression test added
- **Label:** `bug`
- **Source:** synced from upstream `akvelon/flutter-code-editor#259`
- **Reported symptoms:**
  1. Scrolling the editor leaves the line numbers behind — they "escape the
     widget" and stay pinned at the top.
  2. The line-numbers sidebar looks much wider than it needs to be.

## Root cause named by the report

Upstream filed it against an unused `_numberScroll`: the gutter was handed no
scroll controller, so it had nothing to drive it.

## What this fork actually has

`lib/src/code_field/code_field.dart:290-292` creates one
`LinkedScrollControllerGroup` and takes two controllers off it:

```dart
_controllers = LinkedScrollControllerGroup();
_numberScroll = _controllers?.addAndGet();
_codeScroll = _controllers?.addAndGet();
```

`_numberScroll` is handed to the gutter (`code_field.dart:637`) and
`_codeScroll` to the editor's `TextField` (`code_field.dart:526`). Both groups
are disposed together in `dispose()` (`code_field.dart:335-336`). The controller
is therefore not dead code on this fork — the wiring the upstream issue asks for
is already in place.

## How that was verified

Regression test, `test/src/code_field/line_numbers_follow_scroll_test.dart`:

- **drag** — six 20px drags of the editor, then assert the gutter's
  `ScrollPosition.pixels` is within 1px of the editor's, and that the gutter has
  not scrolled past its own `maxScrollExtent` (that is the "escaped the widget"
  failure).
- **jump to the bottom** — `jumpTo(maxScrollExtent)` and assert the gutter
  lands on its own `maxScrollExtent` within 1px, i.e. the last line number is on
  screen.
- **`wrap: true`** — the same jump with wrapping on, because the wrap path
  measures its own row heights and is the one place the two scroll views could
  disagree about how long their content is.

All three pass on this branch.

## Conclusion

The named root cause is absent here and the symptom does not reproduce, so no
source change is warranted. The test lands anyway: it is cheap, it pins the
behaviour the issue cares about, and it is the thing that will catch a future
regression of the wiring.

## The second half of the report (sidebar width)

"Why is the line numbers side bar so wide?" is a design question rather than a
defect, and the width comes from `GutterStyle.width` minus the columns that are
switched off (`gutter.dart:61-64`). It is worth a `spec`-labelled issue of its
own rather than a rider on this bug.
