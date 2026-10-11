# Register a custom language

Fork issue #89, upstream `akvelon/flutter-code-editor#267`. `spec`, severity
`low`, backlog rank 8.

## The ask

> how can i add a not exist language

The reporter wanted to highlight a language this package does not ship and
described reaching for `highlight.registerLanguage('hello', ...)` before handing
the result to `CodeController.language`.

## What is actually true

The controller already handles it. `CodeController.set language`
(`code_controller.dart:268`) takes the mode it is handed, registers it under
`language.hashCode.toString()` as the key, and `_createCode`
(`code_controller.dart:1009`) parses with that key:

```dart
highlighted: highlight.parse(text, language: _languageId),
```

So the registration the reporter assumed they had to do themselves is done for
them, under a key they do not control. Calling `highlight.registerLanguage`
with a name of their own is at best dead work — that name is not the key the
parse uses — and at worst harmful, if the name they picked collided with the
controller's synthetic `hashCode` key and replaced the real mode.

## The change

No behaviour change. This is a discoverability gap:

- A doc comment on `CodeController.language` stating that any `Mode` works and
  that `highlight.registerLanguage` must not be called by the host.
- `test/src/code_field/register_custom_language_test.dart` — 4 tests pinning
  the contract: the mode round-trips through the setter, the language id
  becomes its `hashCode`, the mode's own keyword and string rules reach the
  rendered span, and switching to an unlisted mode and back leaves both
  working.

## Acceptance criteria

- [x] `CodeController.language` documents that any `Mode` works as-is.
- [x] `CodeController.language` documents that the host must not call
      `highlight.registerLanguage`.
- [x] A test proves a hand-built `Mode` highlights without any extra call.
- [x] No public API changes; no default behaviour changes.
