# Tasks: Re-editor Migration

## Phase 1: Spike (verified)
- [x] T001 Add re_editor to a scratch example and render 50k-line doc; measure latency
  - Scratch project: /tmp/re_editor_spike
  - BUILD+SETTLE for 50,000 lines: ~1832ms (test passed)
  - Virtualized rendering confirmed (only visible lines laid out)

## Phase 2: Core controller
- [x] T002 Implement new CodeController on re_editor's controller
  - `CodeLineEditingController` is factory-only, so `CodeController` cannot
    subclass it: the bridge is composition, not inheritance.
  - `ReEditorCodeController` (lib/src/code_field/re_editor_controller.dart)
    wraps one and translates text + selection.
  - `LinePositionMapper` (lib/src/code_field/line_position_mapper.dart) maps
    global offsets to (line, column) and back; 6 tests.
- [x] T003 Port hidden ranges / named sections
  - The bridge renders the controller's *visible* text and writes edits back
    through `CodeController.value`, so the controller's own diff keeps the
    full text and its hidden ranges intact.

## Phase 3: Rendering
- [x] T004 Rewrite CodeField using CodeEditor
  - `CodeFieldRe` (lib/src/code_field/code_field_re.dart) renders via
    `CodeEditor` and bridges both directions with the controller.
  - 3 tests: renders, edit reaches the controller, fold hides lines.
- [x] T005 Port gutter with fold toggles — `lib/src/gutter/code_gutter.dart`, a leaf render object that paints the document's own line numbers, the issue glyphs and the fold chevrons from the paragraphs re_editor has laid out. Tests: `test/src/gutter/code_gutter_test.dart` (3).
- [ ] T006 Port line background layer

## Phase 4: Highlighting & themes
- [x] T007 Migrate language modes to re_highlight — `lib/src/highlight/re_highlight_mode_converter.dart` converts a `package:highlight` grammar into a `re_highlight` one. Tests: `test/src/highlight/re_highlight_mode_converter_test.dart` (7).
- [x] T008 Map CodeTheme styles — the package's `CodeThemeData.styles` map is handed to re_editor as it is: the grammars name their scopes the way the themes are keyed. `lib/src/code_theme/re_highlight_theme.dart`.

## Phase 5: Folding
- [ ] T009 Port block detection to chunk analyzer
- [ ] T010 Preserve visible closing line behaviour

## Phase 6: Autocomplete & search
- [ ] T011 Re-wire autocomplete
- [ ] T012 Re-wire search

## Phase 7: Tests
- [ ] T013 Migrate test suite

## Phase 8: Playground
- [ ] T014 Update HighlightedCodeEditor

## Phase 9: Release
- [ ] T015 Bump major version, changelog, migration doc