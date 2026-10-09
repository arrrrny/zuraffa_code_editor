# Spec Issue: Outdent on Backspace (`CodeModifier` cannot register on `'\b'`)

- **Slug**: outdent-on-backspace
- **Number**: 004
- **Fetched**: 2026-10-09
- **Issue**: 21
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/21
- **State**: open
- **Author**: arrrrny
- **Labels**: spec

## Body

Upstream body verbatim:

```
I would like to implement a "dedent on backspace" but it seems a `CodeModifier` that wants to register itself on `'\b'` doesn't work. I checked that the backspace key is delegated to the `CodeController`'s `onKey` method and you could process it there if nothing else works, but I think, a `CodeModifier` which is called on `'\n'` for indentation is the right place to implement this.

I'm using version 0.2.15.
```

Synced from upstream `akvelon/flutter-code-editor#218 — "Outdent on Backspace"`.

## Why it matters

Dedent-on-backspace is standard editor ergonomics. The feature request is small
and well-scoped: pressing Backspace in the leading whitespace of an indented
line removes one indent level, not one space.

## Acceptance criteria

- [ ] Decide the seam: extend the existing modifier mechanism, or add a dedicated action next to `outdent.dart`
- [ ] Backspace in leading whitespace removes a full indent level
- [ ] A regression test pins the behavior (CodeController-level, no widget tree needed)

## Comments

- alexeyinkin: "Registering on `'\b'` does not work because the character to test against is produced from the diff of the two values. Since the value is not +1 char long, modifiers will not be triggered at all. `CodeModifier`s are legacy from the old editor. We are going to drop them in favor of something better when we gather enough use cases like this one."
