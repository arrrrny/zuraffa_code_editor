# Plan — `contextMenuBuilder` on `CodeField` (#12)

`lib/src/code_field/code_field.dart` is the only production file touched.

1. Add `final EditableTextContextMenuBuilder? contextMenuBuilder;` to
   `CodeField` with the `textField.contextMenuBuilder` doc macro, plus the
   matching constructor parameter.
2. Forward it to the `TextField` built in `_CodeFieldState.build`.
3. **The forwarding must never pass a null builder.** `TextField` declares
   `contextMenuBuilder` nullable but defaults it to the private
   `_defaultContextMenuBuilder`; that default is reachable only by leaving the
   argument out. Passing `null` explicitly makes `SelectionOverlay.showToolbar`
   return early (`if (contextMenuBuilder == null) return;`) and the selection
   toolbar disappears entirely — Copy / Select All vanish from every existing
   `CodeField`. So the forwarding site falls back to `TextField`'s own default,
   read off a bare `const TextField().contextMenuBuilder` rather than forked.

Tests live in `test/src/code_field/context_menu_builder_test.dart`.
