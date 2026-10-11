# Issue: HTML/XML highlighting is broken

- **Number**: 103
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/103
- **Upstream**: akvelon/flutter-code-editor#311
- **Labels**: bug, severity:medium
- **Backlog rank**: 6
- **Created**: 2026-10-10

## What is wrong / missing

With `language: xml` the elements are not highlighted and the document
structure is lost.

## Where it lives (as filed)

`highlight mode config`, `lib/src/highlight/`

## Reproduction (as filed)

`CodeField` / `CodeController` with `language: xml` on an HTML or XML document.
