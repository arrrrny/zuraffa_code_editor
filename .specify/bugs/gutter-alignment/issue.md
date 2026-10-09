# Bug Issue: Gutter numbers and code text not aligned; add gutterPadding

- **Slug**: gutter-alignment
- **Fetched**: 2026-10-09
- **Issue**: 6
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/6
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

## What was asked

Gutter numbers and code text are not vertically aligned — there is no way to
add gutter padding. Users who fork the library add a `gutterPadding` property
and it aligns perfectly; without it the gutter is ~4 units misaligned from the
code text. Workarounds posted upstream (matching `height` in both textStyles)
do not fix it — it is a padding/layout issue.

Synced from upstream flutter-code-editor:
- https://github.com/akvelon/flutter-code-editor/issues/312 — "Gutter Numbers and Code Text Not Aligned"

## Why it matters

The gutter is the first thing every user sees; misaligned line numbers make the
editor look broken. The fork has already fixed related line-height drift, so
this is the remaining alignment gap plus the missing `gutterPadding` escape
hatch requested upstream.

## Acceptance criteria

- [ ] Gutter line numbers align vertically with the matching code lines by default (no user-side height workaround needed)
- [ ] A `gutterPadding` (or equivalent) property on GutterStyle/CodeField allows fine-tuning alignment
- [ ] Existing gutter alignment regression tests still pass
- [ ] A test covers the default alignment and the padding property

## Comments

None.
