# Feature: Expose `contextMenuBuilder` on `CodeField`

**Issue:** [arrrrny/zuraffa_code_editor#12](https://github.com/arrrrny/zuraffa_code_editor/issues/12) — synced from upstream `akvelon/flutter-code-editor#315`.
**Label:** `spec`

## Problem

`CodeField` builds a `TextField` but does not forward `contextMenuBuilder`,
unlike Flutter's own `TextField`/`EditableText`. Apps cannot replace the
selection toolbar, add their own actions (search, format, go to line), or
otherwise match platform/design requirements.

## Scope

Add a nullable `EditableTextContextMenuBuilder? contextMenuBuilder` to
`CodeField` and forward it to the editor's `TextField`. Keyboard shortcuts
(search, comment, indent, Tab) stay wired through `FocusableActionDetector` and
are unaffected.

## Non-goals

- `contextMenuIsEmpty`: `TextField` exposes no such parameter. Returning an
  empty widget from the builder achieves the same suppression.
- Per-item filtering of the *default* menu: that is what a custom builder is
  for.

## Acceptance criteria

1. `CodeField(contextMenuBuilder: ...)` renders what the builder returns in
   place of the platform selection toolbar.
2. The builder receives the editor's real `EditableTextState` (text, selection,
   `contextMenuAnchors`), so an app can build from it.
3. Omitting the builder leaves the platform menu exactly as before.
4. Returning an empty widget from the builder leaves no menu.
