# Test list — `contextMenuBuilder` on `CodeField` (#12)

1. The issue's proposed API (`AdaptiveTextSelectionToolbar` fed from
   `editableTextState.contextMenuAnchors`) replaces the toolbar.
   → RED without the forwarding: no `EDITOR_MENU` in the tree.
2. The builder is handed the editor's own `EditableTextState`; its
   `textEditingValue` matches the controller's text and selection.
   → RED without the forwarding: the builder is never consulted.
3. With no builder the platform menu still appears and still carries
   `TextSelectionToolbarTextButton`s (Copy / Select All).
   → RED without this safeguard: `TextField`'s default `contextMenuBuilder` is
   only applied by *omitting* the argument, so forwarding an explicit null
   turns the toolbar off outright.
4. A builder returning `SizedBox.shrink()` leaves no menu behind.
   → RED without the `??` fallback at the forwarding site (an explicit null
   also suppresses it).
