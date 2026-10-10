# #26 — Multiple CodeFields in a TabBarView crash with a null-check error

- **Status:** verified not reproducible on this fork; guard test added
- **Label:** `bug`
- **Source:** synced from upstream `akvelon/flutter-code-editor#174`
- **Reported symptom:** `Null check operator used on a null value` from
  `_CodeFieldState.initState.<anonymous closure>`.

## The site the report names

`lib/src/code_field/code_field.dart:308-315`, the post-frame callback registered
in `initState`:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) {
    return;
  }
  final double width = _codeFieldKey.currentContext!.size!.width;
  final double height = _codeFieldKey.currentContext!.size!.height;
  windowSize = Size(width, height);
});
```

Two null-check operators: one on the `GlobalKey`'s context, one on the render
box's size.

## What this fork already has

The *same* job is done, guarded, in `rebuild()` (`code_field.dart:368-384`) —
with a comment recording the observation that led to the guard:

```dart
// For some reason _codeFieldKey.currentContext is null in tests
// so check first.
final context = _codeFieldKey.currentContext;
if (context != null) {
  final double width = context.size!.width;
  ...
}
```

So the family of crash this report belongs to has already been hardened here,
in three places: this guard, the `_isEditorBoxLaidOut` checks in
`_onTextChanged` and `_updatePopupOffset`, and `scrollOffsetOrZero`
(`code_field.dart:233-238`, added for upstream #275, a sibling report of the
same "notification lands in a window where the scroll view has no position"
shape).

## How it was verified

`test/src/code_field/tabbarview_multiple_codefields_test.dart`, three tests:

1. **switching tabs between three CodeFields** — forward through the tabs and
   back, `takeException()` stays null.
2. **a tab that is never shown** — `initialIndex: 3` of four, so the earlier
   fields are the ones the report says crash.
3. **dropping a tab while another is on screen** — rebuild with fewer tabs.

Also probed and found not to reproduce: `IndexedStack` with an inactive index,
an `Offstage` sibling, and two CodeFields in a `Column`. A widget-tree probe
showed `TabBarView` builds only the tab that is on screen (1 `CodeField` alive
at a time, and 1 after each tab switch), so the field whose `initState`
callback would run is always one that has been laid out — which is why the
null read never happens on this fork.

## Conclusion

No source change is warranted: the reported stack's crash shape does not
reproduce, and the site is one of a family whose other members are already
guarded here. The test lands as a guard on the `TabBarView` case so a future
change to the popup positioning path gets caught with a real failing test
rather than a user's stack trace.

## Residual risk worth recording

`code_field.dart:312-313` still carries the unguarded `!`s. Making it as safe
as its twin in `rebuild()` is a two-line change, but each guard branch it adds
has to be reachable from a test under this repo's 100% coverage gate, and I
could not build a state in which `currentContext` is null or `size` is null.
Left alone deliberately rather than shipped untested; a reproduction of the
guard would close both.
