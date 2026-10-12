# Implementation Plan: per-line-background

**Branch**: `spec/per-line-background-86` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `.specify/specs/per-line-background-86/spec.md`

## Summary

Add one nullable hook, `CodeController.lineBackgroundBuilder`
(`Color? Function(int lineIndex)?`), that lets a host tint the background of
individual code lines. The hook is consulted once per **rendered** line during
`CodeController.buildTextSpan()` and the tint is drawn as a background layer
behind the text, sized from the per-row heights the editor already measures for
gutter alignment. The default (`null`) produces today's widget tree and today's
span tree unchanged.

The hard requirement, and the reason this is not a two-line change, is the tint's
**extent**: `TextStyle.backgroundColor` covers only the glyph run (measured — see
`research.md`), so a tint applied through styles alone stops at the last
character of the line. The plan therefore paints rows, not styles.

## Technical Context

**Language/Version**: Dart 3 / Flutter (pubspec `environment:`; local SDK 3.47.5,
CI pins 3.19.6 — nothing newer than 3.19.6 may be used, so no
`withValues`-era-only APIs are assumed and no non-exhaustive `switch` may be
introduced).

**Primary Dependencies**: `flutter` (widgets/editable-text), `equatable`,
`meta`, `highlight`-family syntax highlighting already vendored under
`lib/src/`. No new dependency.

**Storage**: N/A — the hook is transient render state on the controller.

**Testing**: `flutter_test` (widget + unit), run `--concurrency=2` always.
Coverage gate: `python3 tool/coverage_gate.py --min 100`, CI-identical (generate
`test/coverage_helper_test.dart` importing every non-`*_web.dart` file under
`lib/`, run `flutter test --coverage --concurrency=2`, gate, then remove the
helper and `coverage/`). `EXEMPT_LINES` is pinned by line number, so any
insertion above an exempted line must be renumbered.

**Target Platform**: all Flutter targets the package already supports (mobile +
web via the existing conditional-import split). The feature adds no
platform-specific code and no new `_web.dart` file.

**Project Type**: library (Flutter package).

**Performance Goals**: the hook runs once per rendered line per rebuild; the
background layer is only built when the hook is non-null, and the row heights it
consumes are already cached in `_wrappedRowHeights` (`code_field.dart:722`). The
existing `no_language_keystroke_test.dart` pin is the regression guard for the
keystroke path.

**Constraints**:
- No text character may be added, removed or reordered — the span tree is what
  `EditableText` edits and hit-tests.
- The tint must sit **behind** `SearchResultHighlightedBuilder`'s per-match
  background so the search colour still wins on a matched run.
- The tint must stay aligned with the text through folds, hidden sections,
  wrapping and vertical scrolling.

**Scale/Scope**: 3 source files, 2–3 test files, ~1 public field. No new public
type, no new export, no new file in `lib/` beyond what already exists.

## Constitution Check

The constitution is still the unmodified Spec Kit template — no project
principles are ratified, so there is nothing to violate by construction. The two
gates that do bind in practice are both satisfied:

| Gate | Status |
| --- | --- |
| Test-First (non-negotiable in the template) | The TDD loop is driven by `test/src/code_field/per_line_background_test.dart`, written red before the implementation. |
| 100% coverage gate | Every new branch is either covered or proved dead and exempted with a written reason in `tool/coverage_gate.py`. |

*Re-checked after Phase 1 design*: still satisfied. No violation to record in
Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
.specify/specs/per-line-background-86/
├── plan.md              # this file
├── research.md          # Phase 0 output — the mechanism decision
├── data-model.md        # Phase 1 output
├── contracts/
│   └── code-controller-hook.md
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lib/src/code_field/
├── code_controller.dart     # + lineBackgroundBuilder field, plumbed into _createTextSpan
├── span_builder.dart        # + lineIndex per rendered span (authoritative source)
├── code_field.dart          # + background layer behind the TextField (rowHeights + linked scroll)
└── line_background.dart     # NEW: the background-layer widget (private, not exported)

test/src/code_field/
└── per_line_background_test.dart   # NEW: red→green TDD tests
```

**Structure Decision**: single Flutter package, flat `lib/src/<concern>/`
layout it already uses. The background layer is a private widget under
`lib/src/code_field/` mirroring how `gutter.dart` is a private widget; because it
is private it is not exported, but it still has to be imported by
`test/coverage_helper_test.dart`'s generator to be visible to lcov.

## Complexity Tracking

No unjustified violations. The single non-obvious piece of machinery — a second
scrollable linked to the editor's scroll group — is already the established
pattern in `code_field.dart` for the gutter (`_controllers = LinkedScrollControllerGroup()`,
`code_field.dart:355-357`), so the feature adds no new concept, only a second
user of an existing one.
