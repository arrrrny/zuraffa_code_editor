# Bug Issue: Null check operator crash on caretFullHeight!

- **Slug**: caret-full-height-null-crash
- **Fetched**: 2026-10-09
- **Issue**: 5
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/5
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

## What was asked

Users constantly get uncaught exceptions `Null check operator used on a null
value`, traced to `caretFullHeight!` in the code field.

Synced from upstream flutter-code-editor:
- https://github.com/akvelon/flutter-code-editor/issues/282 — "Constantly getting exceptions because of Null check operator used on a null value"

Upstream body verbatim:
```
Hi! Thank you for taking the time to read this.

I am constantly getting uncaught exceptions because of this error: Null check operator used on a null value.

[image]

It's probably because of this: `caretFullHeight!`
```

## Why it matters

An unguarded `!` in the render layout crashes the app whenever the condition it
assumes (a non-null caret height) does not hold — e.g. an empty field, a custom
TextStyle without height, or before first layout. It is a hard crash in user
code, reported repeatedly upstream.

## Acceptance criteria

- [ ] The null-check operator crash path is removed or guarded so a null `caretFullHeight` degrades gracefully
- [ ] A regression test exercises the previously-crashing path and passes
- [ ] No behavior change for the non-null (normal) path

## Comments

None.
