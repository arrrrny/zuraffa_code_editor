# Feature Issue: Expose `contextMenuBuilder` on `CodeField`

- **Slug**: context-menu-builder
- **Fetched**: 2026-10-09
- **Issue**: 12
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/12
- **State**: open
- **Author**: arrrrny
- **Labels**: spec

## Body

Upstream body verbatim (excerpt):

```
### Problem
`CodeField` does not expose a way to customize the text selection context menu
(copy / select all / custom actions), unlike Flutter's `TextField` and
`EditableText`, which provide `contextMenuBuilder`.
...
### Request / Proposal
Expose a contextMenuBuilder (or equivalent) on CodeField, and forward it
internally to the underlying EditableText.

Example API:
```dart
CodeField(
  controller: _codeController,
  contextMenuBuilder: (context, editableTextState) {
    return AdaptiveTextSelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      children: const [SelectionOptions()],
    );
  },
)
```
```

Synced from upstream `akvelon/flutter-code-editor#315 — "Missing contextMenuBuilder
support in CodeField"`.

## Acceptance criteria

- [ ] `CodeField.contextMenuBuilder` exists, defaults to `null`, and is forwarded to
      the internal `EditableText`
- [ ] Default behavior is byte-identical to today when the parameter is not passed
- [ ] A widget test proves a custom builder's widget appears on selection
