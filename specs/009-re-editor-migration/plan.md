# Implementation Plan: Re-editor Migration

**Branch**: `009-re-editor-migration`
**Date**: 2026-10-20
**Spec**: `specs/009-re-editor-migration/spec.md`

## Summary

Migrate `zuraffa_code_editor` from a `TextField`/`EditableText` rendering core
(single paragraph, O(n) per keystroke) to `re_editor` (line-virtualized), so
large files edit and scroll smoothly, while preserving syntax highlighting,
folding (with visible closing lines), autocomplete, search, themes, gutter, hidden
ranges, named sections, RTL, and undo/redo. Backward compatibility is not a
concern.

## Technical Context

- **Language**: Dart (Flutter), SDK >=3.11.0
- **Framework**: Flutter (mobile/desktop/web)
- **New dependency**: `re_editor: ^0.10.0`, `re_highlight: ^0.0.3`
- **Removed/changed**: `flutter_highlight`/`highlight` from render path; `linked_scroll_controller`, `scrollable_positioned_list` (replaced by re_editor scroll controllers)
- **Testing**: `flutter_test` (widget tests), `mocktail`
- **Target platforms**: all (android, ios, linux, macos, web, windows)
- **Performance goal**: <16ms keystroke-to-paint, 60fps scroll on 50k-line docs
- **Constraints**: no `dart:io` in lib (web support); preserve `code.text` full-source semantics

## Constitution Check

- Library package, all platforms: maintained (re_editor supports all).
- No `dart:io`: maintained.
- Test coverage gate 100%: new tests required; migration will rewrite many.
- Concurrency cap 2: respected in CI.

No violations.

## Project Structure

```
lib/src/
  code_field/        # rewritten on re_editor
  code/              # line model adapted
  folding/           # chunk analyzer port
  autocomplete/      # re-wired
  search/            # re-wired to CodeFindController
  code_theme/        # style-key mapping
  gutter/            # re-implemented
  hidden_ranges/     # ported
  ...
specs/009-re-editor-migration/
  spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
```

## Phases

See `doc/migrating/re_editor_migration_plan.md` for the detailed 9-phase plan.
High level:

1. Spike: render 50k-line doc in re_editor; measure.
2. Core controller on re_editor's controller.
3. Rendering rewrite (CodeField -> CodeEditor).
4. Highlighting & themes.
5. Folding (chunk analyzer, visible closing line).
6. Autocomplete & search.
7. Tests (rewrite as needed).
8. Playground update.
9. Release.

## Research (Phase 0)

See `research.md`.

## Design (Phase 1)

See `data-model.md`, `contracts/`, `quickstart.md`.