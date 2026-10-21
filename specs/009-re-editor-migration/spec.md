# Feature Specification: Re-editor Migration

**Feature Branch**: `009-re-editor-migration`

**Created**: 2026-10-20

**Status**: Draft

**Input**: User description: "Migrate zuraffa_code_editor from TextField-based rendering to re_editor (Reqable) for virtualized line rendering and large-file performance. Full plan in doc/migrating/re_editor_migration_plan.md. Backward compatibility is not a concern."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit large files without lag (Priority: P1)

As a developer using the editor in `dws_playground` (and any other host), I want
typing, scrolling, and folding to stay responsive on documents of tens of thousands
of lines, so that the editor is usable on large config files.

**Why this priority**: This is the core problem motivating the migration; the
current TextField-based rendering re-lays out the whole document on every
keystroke.

**Independent Test**: Open a 50,000-line document in the editor, type characters
at the end, and verify keystroke-to-paint latency stays under 16ms and scrolling
stays at 60fps.

**Acceptance Scenarios**:

1. **Given** a 50,000-line document is loaded, **When** the user types a
   character, **Then** the edit is reflected without perceptible lag.
2. **Given** a 50,000-line document, **When** the user scrolls, **Then** only
   visible lines are laid out and scroll stays smooth.
3. **Given** a large document, **When** the user folds/unfolds a block,
   **Then** the fold completes without freezing the UI.

---

### User Story 2 - Preserve existing editing features (Priority: P2)

As a host developer, I want syntax highlighting, folding with visible closing
lines, autocomplete, search, themes, gutter with line numbers and fold toggles,
and named/hidden line ranges to keep working after the migration, so that no
capability is lost.

**Why this priority**: The package's value is its feature set; a migration that
drops features is not acceptable.

**Independent Test**: Run the existing behaviour test suite against the new
rendering core and confirm all previously-supported features still function.

**Acceptance Scenarios**:

1. **Given** a Dart/JSON/XML document, **When** it is rendered, **Then** syntax
   highlighting matches the previous output.
2. **Given** a foldable block, **When** collapsed, **Then** the closing line
   remains visible (existing behaviour).
3. **Given** autocomplete triggers, **When** typing, **Then** suggestions appear
   and accept with Tab.
4. **Given** a search query, **When** searching, **Then** matches are highlighted
   and navigable.

---

### User Story 3 - Keep host integration working (Priority: P2)

As a `dws_playground` maintainer, I want `HighlightedCodeEditor` to work against
the new core with minimal changes, so that the playground keeps its hover docs,
format, and fold-safe external text updates.

**Why this priority**: The playground is the primary consumer and must not break.

**Independent Test**: Load the playground, edit a large config, format it, toggle
folds, and confirm no data loss (full source preserved across fold/unfold).

**Acceptance Scenarios**:

1. **Given** an external text update while folds are active, **When** applied,
   **Then** folded-away lines are not spliced into the new text.
2. **Given** a folded editor, **When** reading `code.text`, **Then** it returns
   the full source regardless of fold state.

---

### Edge Cases

- What happens when a document has zero lines or a single line?
- How does the editor handle extremely long single lines (no newlines)?
- What happens when a fold range becomes invalid after an edit?
- How does autocomplete behave at end-of-file?
- What happens on web (no `dart:io`)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The editor MUST render documents using a line-virtualized view so
  that only visible lines are laid out and painted.
- **FR-002**: The editor MUST preserve syntax highlighting for all currently
  supported languages (Dart custom mode, JSON, XML/HTML).
- **FR-003**: The editor MUST support code folding with visible closing lines.
- **FR-004**: The editor MUST support autocomplete with custom word lists and
  Tab acceptance.
- **FR-005**: The editor MUST support search and replace with match highlighting.
- **FR-006**: The editor MUST support themes via `CodeTheme`/`CodeThemeData`.
- **FR-007**: The editor MUST display a gutter with line numbers and fold toggles.
- **FR-008**: The editor MUST support hidden line ranges and named sections.
- **FR-009**: The editor MUST expose `code.text` returning the full source
  independent of fold state.
- **FR-010**: The editor MUST support read-only regions.
- **FR-011**: The editor MUST support undo/redo.
- **FR-012**: The editor MUST support RTL text direction.
- **FR-013**: The public `CodeField` name MUST be retained (implementation may
  change).

### Key Entities

- **CodeController**: Owns text, selection, folds, hidden ranges, and analysis.
- **FoldableBlock**: A collapsible line range with a visible closing line.
- **HiddenLineRanges**: Set of lines hidden by folds/sections.
- **CodeTheme**: Map of style keys to `TextStyle`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Editing a 50,000-line document keeps keystroke-to-paint latency
  under 16ms on a mid-range machine.
- **SC-002**: Scrolling a 50,000-line document holds 60fps.
- **SC-003**: All previously-supported features (highlight, fold, autocomplete,
  search, themes, gutter, hidden ranges, RTL, undo/redo) remain functional.
- **SC-004**: The playground loads and edits large configs without data loss
  across fold/unfold.
- **SC-005**: The test suite passes after migration (rewritten as needed).

## Assumptions

- Backward compatibility is not a concern; the public API may change.
- `re_editor` 0.10.0 (available in pub cache) is the rendering foundation.
- `highlight` may be retained for the analyzer's `Mode`/`Result` types unless
  migrated to `re_highlight`.
- The migration is a multi-phase effort estimated at 3-4 weeks; this spec covers
  the full scope, implementation will be phased.
- `code_forge` was considered but rejected for this scope due to heavier
  dependency surface (LSP/AI); may be revisited if LSP is needed.