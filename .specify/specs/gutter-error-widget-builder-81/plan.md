# Plan: gutter error popup builder

**Spec:** ./spec.md
**Issue:** [arrrrny/zuraffa_code_editor#81](https://github.com/arrrrny/zuraffa_code_editor/issues/81) (remaining half — the per-type icons landed already)
**Label:** `spec`

## Design

One nullable field on `GutterStyle`, one call site in the gutter. The change is
additive and the default path is untouched.

### 1. `lib/src/line_numbers/gutter_style.dart`

```dart
final Widget Function(Issue issue, TextStyle popupTextStyle,
    BoxDecoration? popupDecoration)? errorPopupBuilder;
```

Placed next to `errorPopupDecoration` — the two fields style the same popup at
different granularities, and `errorPopupTextStyle`/`errorPopupDecoration` are the
values the builder receives resolved.

`copyWith` gains the parameter in the same relay form as its siblings
(`errorPopupBuilder: errorPopupBuilder ?? this.errorPopupBuilder`). No new
import beyond what the file already has (`flutter/material.dart` provides
`Widget`; `Issue` comes through the existing import chain used by
`issueIcon(IssueType)` — verify at edit time).

### 2. `lib/src/gutter/gutter.dart` — `_fillIssues`

```dart
tableRows[lineIndex].children[_issueColumn] = _sized(
  style.errorPopupBuilder?.call(
    issue,
    style.errorPopupTextStyle ?? (throw ...),
    style.errorPopupDecoration,
  ) ?? GutterErrorWidget(
    issue,
    style.errorPopupTextStyle ?? (throw ...),
    icon: Icon(style.issueIcon(issue.type), color: Colors.red, size: iconSize),
    popupDecoration: style.errorPopupDecoration,
  ),
  lineIndex,
);
```

Resolving `errorPopupTextStyle` once above the expression keeps the duplicated
null-throw identical in both arms: the `?? (throw ...)` is existing behaviour that
must survive verbatim, so it stays as one local, not two.

The builder arm is one branch, the null arm is the other; both need a test. No
other call site constructs `GutterErrorWidget` for the gutter path, so there is
nothing else to thread the builder through.

### 3. Coverage

`gutter.dart` is 100%-gated by line, so the builder arm must be executed by a
widget test that mounts the gutter with the style set — a unit test on
`GutterStyle` alone cannot reach it. The existing `error_icon_override_test.dart`
pattern (mount `CodeField`, assert on the widget tree) is the template; the
custom-widget assertion is `find.byType(CustomErrorPopup)` plus a positive tap
through the host-supplied widget if the builder wires one.

## Order of work

1. `test/src/line_numbers/gutter_error_widget_builder_test.dart` — red: the
   `GutterStyle` constructor rejects the unknown parameter, so the file does not
   compile until the field exists.
2. Default arm pins: gutter with no builder renders `GutterErrorWidget` with the
   resolved icon, text style and decoration (characterization, guards the
   "default does not change" criterion).
3. `errorPopupBuilder` on `GutterStyle`, `copyWith` relay, gutter call site.
   Override pins go green.
4. `copyWith` carries the field (unit, no widget).
5. CHANGELOG entry, Spec-Kit artifacts, coverage gate.

## Risks

- **The null-throw.** `errorPopupTextStyle` is asserted non-null at the call
  site today; the builder receives that resolved value. The throw stays in exactly
  one place so a null style still fails the same way with the builder set — a
  test that sets a builder but no text style pins it.
- **`_sized` wrapping.** The builder's return is wrapped in `_sized` like any
  other issue-column child; a builder returning something with its own intrinsic
  width is sized by the column geometry, not the reverse. Documented in the
  field's doc comment rather than pinned by a fragile layout test.
- **`tool/coverage_gate.py` EXEMPT_LINES are pinned by line number** (same
  gotcha as the icon spec). Any insertion above the exempted line in
  `gutter.dart`/`error.dart` must renumber it.
- **`dart format`/analyze on the long function type.** Formatted exactly as the
  field declaration above; `dart format --set-exit-if-changed` is a gate.
