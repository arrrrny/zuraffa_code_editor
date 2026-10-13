# Spec: horizontal-scrollbar-91

**Issue:** [arrrrny/zuraffa_code_editor#91](https://github.com/arrrrny/zuraffa_code_editor/issues/91) — synced from upstream `akvelon/flutter-code-editor#281`.
**Label:** `spec` · **Severity:** `low`

## What was asked

> I could really use a horizontal scrollbar, because sometimes the code is pretty
> wide. I don't want to use text wrapping, either... In a fork of this repository,
> I tried adding it myself, but I don't think I'm good enough at Flutter, yet, to
> be able to do it properly. Because right now, the scroll bar is only visible at
> the bottom of the scrollview, instead of always visible at the bottom of the
> screen.

The acceptance criteria are the whole contract: a bar that stays pinned to the
bottom of the **viewport**, the vertical scrollbar unaffected, wrapping unchanged,
and tests pinning the placement.

## What exists today

`_wrapInScrollView` (`lib/src/code_field/code_field.dart:516`) has two shapes:

- **`wrap: true`** — a `Padding` around the field. No horizontal scroll view, no
  horizontal reach, nothing to show a bar for.
- **`wrap: false`** (the case this issue is about) — the field is wrapped in
  `IntrinsicWidth` > `Column` of [a zero-height `Text(longestLine)` used to size
  the column, the field itself], and that column is the child of a
  `SingleChildScrollView(scrollDirection: Axis.horizontal,
  controller: _horizontalCodeScroll)`.

The `Text(longestLine)` line is what makes horizontal scrolling work at all: it
gives the column a *content* width wider than the viewport, so the field is laid
out at the full width of its longest line and the scroll view has something to
scroll. `_horizontalCodeScroll` is assigned unconditionally in `initState`
(`code_field.dart:394`).

There is no `Scrollbar` anywhere in `lib/`.

## The trap the reporter fell into

A `Scrollbar` placed **inside** the scroll view is a `RenderBox` sibling of the
content: it is laid out *at the end of the column*, below the last line of code,
so it is only reachable by scrolling to the end — exactly what the issue
describes. A `Scrollbar` around the scroll view has the scroll view's own box,
which is the editor viewport, so it is pinned to its bottom edge whatever the
content does.

## Decision

Wrap the existing `SingleChildScrollView` in a `Scrollbar` and pass it the field's
own controller, so the bar drives the code area's offset and nothing else:

```dart
return Scrollbar(
  controller: _horizontalCodeScroll,
  thumbVisibility: contentWidth > minWidth - widget.padding.right,
  interactive: true,
  child: SingleChildScrollView(...),
);
```

Four decisions, each for a reason:

- **`thumbVisibility` is computed, not hardcoded.** A thumb with
  `thumbVisibility: true` paints even at `maxScrollExtent == 0`, so a hardcoded
  `true` puts a full-width bar on every short file in every app. The reach is
  measured with a `TextPainter` against the *same* `longestLine` and style the
  `IntrinsicWidth` column already measures, plus the 16px padding that trick
  adds, and compared with the viewport width. No listener, no second build pass.
- **The bar is never mounted conditionally.** Mounting it only when it overflows
  was tried first and is a measured failure: inserting a widget above the scroll
  view rebuilds the `SingleChildScrollView` at a different depth, which unmounts
  its `Scrollable` and takes the scroll offset with it. That reset lands on the
  caret reveal `EditableText` schedules while typing, so the code jumped back to
  the left edge on every width change — the caret-reveal test in
  `horizontal_scroll_behaviour_test.dart` failed, and the per-line background
  test (`hands the builder the full, unfolded line index`) failed its
  "second build pass" assertion in the listener-based variant. A stable tree with
  a hidden thumb has neither fault.
- **`interactive: true`.** Flutter defaults `interactive` to false on touch
  platforms, which leaves the thumb a decoration that cannot be dragged. With no
  thumb painted the recognizers find nothing to grab, so a hidden bar stays
  inert.
- **`thumbVisibility` rather than fading.** A thumb that fades out when the
  gesture ends is invisible in exactly the state a wide file is in.

The gutter, the linked vertical scroll controllers, the vertical scrollables and
the `wrap: true` path are untouched.

## Deliverable

| Change | Where |
|---|---|
| `Scrollbar` around the code area's horizontal scroll view | `lib/src/code_field/code_field.dart` (`_wrapInScrollView`) |
| `test/src/code_field/horizontal_scrollbar_placement_test.dart` | 7 tests |

## Verification

- `flutter test test/src/code_field/` → **391 passed** (384 existing + 7 new).
- `dart analyze --fatal-infos` → no issues.
- `dart format --set-exit-if-changed` → clean.
- Three faults injected:
  - thumb always visible → 2 tests red;
  - **bar moved inside the scroll view, the issue's own trap** → 6 tests red;
  - a non-compiling removal was not counted.
