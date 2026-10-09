# Bug Issue: Large files render blank lines past ~1000 lines; high CPU and RAM

- **Slug**: large-files-render-blank-lines
- **Fetched**: 2026-10-09
- **Issue**: 18
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/18
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
If I open a file with more 1000 lines it does not not display correctly after a certain point it only shows blank lines.
Also for these large files widget uses a lot of CPU and RAM.
```

Synced from upstream `akvelon/flutter-code-editor#283 — "Large files do not render correctly"`.

## Why it matters

A file that renders as blank lines past some line count is the editor failing at
its core job. Upstream commenters tie the symptom to gutter height config, and
one reporter fixed rendering by setting an explicit `GutterStyle` height — that
points at the gutter/line-height sync, the same subsystem as issue #6
(gutter alignment) and #19 (line numbers escaping the widget).

## Acceptance criteria

- [ ] Root cause identified: where does line rendering stop past ~1000 lines (gutter height sync, viewport, or line-index mapping)?
- [ ] A large file renders all lines (or at least the visible window) correctly
- [ ] A regression test pins the rendering behavior with a programmatically built long document

## Comments

- peter-kal: "I saw that the problem of lines is fixed by adding height to the GutterStyle property. The performance is good for me, but the situation worsens when typing." Also references #255 (perf with many rows).
- ViscousPot: prototyped chunked loading (500-line chunks, 50-line overlap) on a fork branch; abandoned it in favour of re_editor + mmap2. Repo acknowledged as stale.
