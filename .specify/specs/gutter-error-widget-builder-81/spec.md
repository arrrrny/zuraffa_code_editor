# Spec: gutter-error-widget-builder

Fork issue: #81 · Upstream: akvelon/flutter-code-editor#216
Label: `spec` · Severity: `medium` · Backlog rank: 1

## What was asked

"Please allow me to override the gutter error icon. Currently, it's hardcoded in
`lib/src/gutter/error.dart` and cannot be changed because I cannot provide my own
`GutterErrorWidget`, or even better, provide three icons based on the
`IssueType` using the `GutterStyle`."

## What exists today

The ask has two halves. The first — per-`IssueType` icons on `GutterStyle` — is
already delivered in this fork (`errorIcon` / `warningIcon` / `infoIcon` plus
`GutterStyle.issueIcon(IssueType)`, and `GutterErrorWidget.icon` for a host that
mounts the widget directly).

The second half is still open: a host that wants a **different popup**, not a
different glyph. `GutterWidget._fillIssues`
(`lib/src/gutter/gutter.dart:227`) constructs `GutterErrorWidget` itself, per
issue, with the popup text style, the glyph, and the decoration. There is no
injection point anywhere on the path from `CodeField` to that constructor, so
the popup's layout — card vs. plain `Container`, tap targets, an action row,
a custom enter/exit animation — is frozen for every consumer of the package.
The `errorPopupDecoration` escape hatch (#82) only re-skins the container; the
content and behaviour are still the package's.

This is also the surface the upstream repo acknowledged and deferred: fork
issue #82's CHANGELOG entry records that "a `popupBuilder` that would replace
the whole overlay is deliberately not in this change".

## What this spec adds

A single hook on `GutterStyle`:

1. **`GutterStyle.errorPopupBuilder`** — a nullable
   `Widget Function(Issue issue, TextStyle popupTextStyle, BoxDecoration? popupDecoration)?`.
   When set, the gutter calls it per issue instead of constructing
   `GutterErrorWidget`, handing it the same three inputs the built-in widget
   receives. When null, the gutter constructs `GutterErrorWidget` exactly as it
   does today.

## Decisions

- **The default does not change.** A style that sets no builder renders the
  very same `GutterErrorWidget` with the same arguments as before this change.
  The feature is purely additive and opt-in.
- **The builder receives the resolved values, not the style.** It is handed the
  issue, the already-resolved popup `TextStyle`, and the already-resolved
  `BoxDecoration?` — the same triple `GutterErrorWidget` gets. A host that
  wants to re-skin a built-in-style popup can pass them straight through to
  `GutterErrorWidget`, and a host that wants its own widget ignores them. The
  gutter therefore does not re-resolve anything per issue type.
- **The signature is a `Widget` function, not a `GutterErrorWidget` subclass
  hook.** The reporter's words are "provide my own `GutterErrorWidget`"; the
  general form of that is "return the widget the gutter should show", which a
  builder expresses without constraining the host to the built-in widget's
  constructor.
- **`copyWith` is extended**, matching how it already carries the style's other
  fields, so the builder survives theme/derived-style round-trips.

## Out of scope

- Changing `GutterErrorWidget`'s own constructor or behaviour.
- Overriding the icon or the decoration — those already landed (#81 part one,
  #82) and are orthogonal.
- Any change to how the gutter resolves `errorPopupTextStyle` when it is null
  (today that throws; this spec does not touch it).

## Note for whoever edits `gutter.dart` next

`tool/coverage_gate.py` pins `EXEMPT_LINES` by **line number**. Inserting lines
above an exempted line shifts it and the gate goes red with a "matches nothing"
or a bare miss. This spec adds code around `gutter.dart`'s discarded
fold-toggle lambda area; the "stale line exemption" line the tool prints is the
signal to renumber.

## Acceptance criteria

- [ ] `GutterStyle` accepts `errorPopupBuilder`, nullable, typed
      `Widget Function(Issue, TextStyle, BoxDecoration?)?`.
- [ ] The gutter calls the builder per issue when it is set, passing the same
      popup text style, and the same decoration the built-in widget would get.
- [ ] The gutter constructs `GutterErrorWidget` exactly as today when the
      builder is null.
- [ ] A style that sets no builder renders identically to before.
- [ ] `GutterStyle.copyWith` carries the new field.
- [ ] The public API is exported as before (no new file needed).
- [ ] Coverage stays at the 100% gate; new branches are covered or proved dead.

## Gates

`flutter test` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
