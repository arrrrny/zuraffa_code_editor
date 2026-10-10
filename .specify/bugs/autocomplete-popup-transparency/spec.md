# Spec: autocomplete-popup-transparency

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/34
(upstream akvelon/flutter-code-editor#273, `[question]`).

## Requirement

The autocomplete suggestion popup must always be readable: its background
must be an opaque colour. Today the popup inherits the editor's background,
which is deliberately set to null whenever `CodeField.decoration` is used
(a very common way to theme the field), leaving the popup fully transparent
with the code showing through it. There must also be a user-facing way to
choose the popup background.

## Acceptance

- With a `decoration` set, the popup's background is opaque, not null.
- An explicit `CodeField.autocompleteBackground` wins over the editor
  background and over the theme fallback.
- Without a decoration, the popup background still equals the editor
  background — today's default behaviour is preserved.
- No regression: full suite green, `dart analyze --fatal-infos` clean,
  format clean.

## Non-goals

- Restyling the popup beyond its background (border, item colours).
- Making the popup translucent-by-choice (an opacity knob).
- Touching the search overlay, which has its own colour resolution.
