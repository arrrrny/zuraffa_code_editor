# Spec: gutter-error-icon-override

Fork issue: #81 · Upstream: akvelon/flutter-code-editor#216
Label: `spec` · Severity: `medium` · Backlog rank: 1

## What was asked

"Please allow me to override the gutter error icon. Currently, it's hardcoded in
`lib/src/gutter/error.dart` and cannot be changed because I cannot provide my own
`GutterErrorWidget`, or even better, provide three icons based on the
`IssueType` using the `GutterStyle`."

## What exists today

`lib/src/gutter/error.dart` declares one module-level constant:

```dart
const errorIcon = Icon(Icons.cancel, color: Colors.red, size: 16);
```

and `GutterErrorWidget` renders it as the `MouseRegion` child. The symbol is
public but a host cannot reach it through any style — the widget is constructed
by `GutterWidget._fillIssues`, which passes only the `Issue` and the popup text
style. The result is that every issue type (`IssueType.error`, `.warning`,
`.info`) renders the same red cancel glyph, and there is no supported way to
change it.

## What this spec adds

Two escape hatches at two levels of granularity, because the ask names both:

1. **`GutterStyle` gains three icon fields**, one per `IssueType`. Each is
   nullable; a null field keeps today's default. This is the "three icons based
   on the `IssueType`" the reporter asked for as the preferable option.
2. **`GutterErrorWidget` gains an optional `icon` widget**, so a host that
   mounts the widget directly (as the package's own tests do) can swap the whole
   thing, not just the glyph.

## Decisions

- **The default does not change.** Warning and info keep the red cancel glyph
  they have always rendered. Distinguishing them by default is a visual change
  nobody asked for; this spec only makes it *possible*.
- **`IconData`, not `Widget`.** The glyph is overridable, the size and the
  colour are not: the issue column is `_issueColumnWidth` (16.0) wide, so a
  16px glyph is part of the row geometry. A host needing more than a glyph
  already has `GutterErrorWidget.icon`.
- **Resolution lives on `GutterStyle`**, as `issueIcon(IssueType)` returning a
  non-null `IconData`. One method keeps the fallback rule in one place and makes
  it directly testable without mounting a widget.
- **`copyWith` is extended**, matching how it already carries the style's other
  fields.

## Out of scope

- A `popupBuilder` / popup `shape` / `borderSide` — that is fork issue #82, the
  same `error.dart` file but a different surface.
- Giving warning/info distinct default icons.
- Sizing or colouring the icon from the style.

## Note for whoever edits `error.dart` next

`tool/coverage_gate.py` pins `EXEMPT_LINES` by **line number**. Inserting lines
above an exempted line shifts it and the gate goes red with a "matches nothing"
or a bare miss. This spec adds 18 lines above `error.dart`'s null-`RenderBox`
guard and 8 above `gutter.dart`'s discarded fold-toggle lambda (3 comment + 5
code), so both entries are renumbered (71→89 and 221→229). Any further
insertion in either file needs the same treatment; the "stale line exemption"
line the tool prints is the signal.

## Acceptance criteria

- [ ] `GutterStyle` accepts `errorIcon`, `warningIcon` and `infoIcon`, each a
      nullable `IconData`.
- [ ] `GutterStyle.issueIcon(IssueType)` returns the matching field when set and
      the shared default when not, and never null.
- [ ] `GutterErrorWidget` takes an optional `icon` widget, defaulting to the
      constant that is rendered today.
- [ ] The gutter renders the icon the style resolves for each issue's own type.
- [ ] A style that sets nothing renders byte-identically to before (same glyph,
      colour and size).
- [ ] `GutterStyle.copyWith` carries the three new fields.
- [ ] The public API is exported as before (no new file needed).
- [ ] Coverage stays at the 100% gate; new branches are covered or proved dead.

## Gates

`flutter test` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
