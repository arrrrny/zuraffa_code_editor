# Changelog

## Unreleased

### Added

- **HTML is reachable and documented as a first-class language**
  ([issue #40](https://github.com/arrrrny/zuraffa_code_editor/issues/40)):
  `highlight` ships no `html` mode — HTML is one of the aliases of its `xml`
  mode, and that mode already classifies the doctype, element names, attributes,
  attribute values, comments and entity references of a real document. The
  README's *Languages › Syntax Highlighting* section now says so instead of
  leaving the reader to conclude from a missing
  `package:highlight/languages/html.dart` that HTML is unsupported, and the
  demo's language picker gained `html` and `xml` entries so the path is
  demonstrable. Pinned by `test/src/highlight/html_language_test.dart`.
  Inside `<script>` and `<style>` bodies the text stays markup rather than being
  re-parsed as JavaScript or CSS, because `highlight`'s `xml` mode declares no
  embedded sub-language for them.

- **`tool/coverage_gate.py` gained a line-level exemption mechanism.**
  `EXEMPT_LINES` removes individual unreachable lines from both the numerator
  and the denominator of the file they sit in — the same contract
  `EXEMPT_FILES` has always had for whole files — and a stale-entry check warns
  when a listed line no longer matches anything in `lcov.info`. Every entry
  carries its proof in the comment above it, and the list is meant to stay
  short: if an exempted line becomes reachable, the test that reaches it is
  added and the entry dropped.

- **22 new test files** closing the reachable coverage gaps left over from the
  previous rounds: the autocompleter's blacklist and unknown-keyword paths, all
  six `Action` delegates of the code field, the tab modifier, `TextSelection`
  extension, named sections, `AbstractAnalyzer.dispose`, the single-line
  comment parser, `KeyEventExtension`, the fallback foldable block parser and
  the parser factory, the gutter fold toggles, the hidden range sort tie-break,
  `SearchNavigationState.copyWith`, the search bar's close icon, the CRLF row
  measurement of a wrapped field, and — new in this round — the gestural surface
  of the completion popup (a tap moves the selection and returns focus, a
  double tap commits the word) plus the recomputation of the search navigation
  index after a mid-search edit.

- **A committed keystroke-latency benchmark.**
  `test/src/code_field/edit_latency_test.dart` measures the median keystroke at
  200, 1000 and 3000 lines, prints the per-line latency, and fails on a
  super-linear regression, so the next report of "sluggish past a few hundred
  rows" starts from numbers instead of a sentence.

- **`CodeField` exposes `contextMenuBuilder`**
  ([issue #12](https://github.com/arrrrny/zuraffa_code_editor/issues/12)):
  an app can now replace the selection toolbar with its own actions (search,
  format, go to line) by passing an `EditableTextContextMenuBuilder`. When no
  builder is given, the field forwards `TextField`'s own default instead of an
  explicit `null`, so the platform menu — Copy, Select All — survives unchanged
  for every existing `CodeField`.

### Fixed

- **`dart analyze` warnings in the new tests** — unused imports removed.

- **A keystroke no longer rebuilds the visible highlight or re-indexes the whole
  document** ([issue #39](https://github.com/arrrrny/zuraffa_code_editor/issues/39),
  upstream `akvelon/flutter-code-editor#255`). `Code.foldedAs` cut and re-split
  the entire highlight tree a second time per keystroke even when it folded
  nothing, `HiddenRanges.cutHighlighted` rebuilt a structurally identical copy
  of that tree whenever nothing was hidden, and `Autocompleter.setText` re-entered
  every word of the document into the autotrie. Each now does only the work the
  edit requires. Median keystroke on a 3000-line document measured 88.7 ms
  before and 77.9 ms after (−12%; −34% at 200 lines). Growth stays linear in
  rows — the remaining ceiling is `highlight.parse` of the whole document, which
  has no incremental API here and is left to issue #22.

### Changed

- **The coverage gate ratchets to 100%.** The measured value is
  `100.00% (3089/3089 lines over 102 files)`; 13 lines are exempted
  individually as provably unreachable (dead branches, defensive guards, the
  `ItemScrollController` assignment in `Popup` that can never observe an
  attached controller, and the fold-toggle lambda that the second loop of
  `Gutter._fillFoldToggles` always overwrites). `--min 97.7` becomes `--min 100`
  in `.github/workflows/dart.yaml`.

- **Generated artifacts are no longer versioned.** `coverage/lcov.info` and the
  `example/ios/Flutter/ephemeral/` output of `flutter pub get` are untracked
  and added to `.gitignore`, so a local coverage run or a plugin re-resolution
  cannot show up as a source change.

## 0.1.2

### Fixed

- **Foldable blocks that merely touch are no longer merged.** `joinIntersecting`
  joined two blocks when the second began on the first block's last line, so
  `}void main(){` — the closer of one block and the opener of the next — became
  a single block and folding the first folded the second
  ([issue #25](https://github.com/arrrrny/zuraffa_code_editor/issues/25)).
  Touching blocks now stay separate (`0..1`, `2..8`, `3..5`, `8..11`).

- **The block below keeps its start on screen.** When a block's closing line
  also opens the following foldable block, the hidden range ends one character
  earlier so the closer keeps a row of its own — and with it the line number
  and the fold toggle the next block hangs there. The guard no longer requires
  the closer to be the line's first token, so a multi-line condition
  (`if (a &&` / `b &&` / `c) {`) is covered too. The upstream glue default
  (`parsers: [  ],`) is unchanged.

## 0.1.1

### Fixed

- **Fold ranges now end at the start of the last line only when that line is a
  closing line** (`)`, `]`, `}` …). 0.1.0 applied this unconditionally, which
  hid only the *newline* before a non-closing last line and glued the
  neighbouring lines together: folding

  ```dart
  // first line
  // second line
  // third line
  ```

  produced `// first line// third line`. Content lines — the tail of a `//`
  comment block, a continued argument, an import group — are hidden whole
  again, exactly as upstream does, while folded closers stay on screen as
  before: `parsers: [  ],`, `void method() {  }`, `ScraperConfig();`.

- **The gutter now uses the code style's line height.**
  `CodeField._buildGutter()` copied `fontSize` and `fontFamily` from the code
  style "for consistency with lines" but not `height`, so gutter rows fell
  back to the font's own metrics — 19 px against the code's 21 px at the
  default style. The two grids therefore drifted ~1.9 px on *every* line,
  reaching ~60 px by line 36 of a typical file. Because the fold chevron is
  centred in its gutter row it inherited that drift, so chevrons climbed above
  the line they labelled (over half a line off by line 9, worse further down).
  The gutter now starts on the code text's top edge with a row pitch equal to
  the rendered line height.

### Added

- `gutter_alignment_test.dart` pins the gutter/code grid invariant — top edge
  and row pitch — in both the folded and unfolded states.
- Comment-block regression tests pinning that non-closing blocks hide their
  last line whole, with no glued text.

## 0.1.0

First release of `zuraffa_code_editor`, a maintained fork of
[`flutter_code_editor` 0.3.5](https://pub.dev/packages/flutter_code_editor).

### Changed

- **Folded blocks keep their closing line visible.** Upstream hid a folded
  block through the end of its last line, so folding `parsers: [ ... ]` left a
  dangling `parsers: [` with no matching `],` — broken-looking code. The fold
  range now ends at the start of the block's last line, so the closing line
  stays on screen: `parsers: [  ],`, `void method() {  }`, `ScraperConfig();`.
  Gutter line numbering, fold-toggle placement and the number of rendered rows
  are all unchanged — only the closing text is added back.
- Repackaged from `flutter_code_editor` to `zuraffa_code_editor`; all imports
  are now `package:zuraffa_code_editor/zuraffa_code_editor.dart`.
- Linting moved from `total_lints` to `flutter_lints`.

### Thanks

Everything except the fold change above is the work of the upstream
[akvelon/flutter-code-editor](https://github.com/akvelon/flutter-code-editor)
contributors. Changes to this fork's own code are dedicated to the public
domain under [CC0](https://creativecommons.org/publicdomain/zero/1.0/).

## 0.3.5

- Fixed line numbers not aligning with lines (https://github.com/akvelon/flutter-code-editor/pull/307)

## 0.3.4

- Added default height to `defaultTextStyle` (https://github.com/akvelon/flutter-code-editor/pull/297).
- Added `disposed` and `mounted` checks to `CodeField` and `CodeController` (https://github.com/akvelon/flutter-code-editor/pull/298).
- Added `UndoHistoryController` to `CodeField` (https://github.com/akvelon/flutter-code-editor/pull/302).
- Added support for `yaml` comments (https://github.com/akvelon/flutter-code-editor/pull/305).

## 0.3.3

- Added `smartDashesType` and `smartQuotesType` to `CodeField` (https://github.com/akvelon/flutter-code-editor/pull/278).
- Added named sections support for JavaScript and TypeScript (https://github.com/akvelon/flutter-code-editor/pull/291).

## 0.3.2

- Flutter 3.22 WASM fixes

## 0.3.1

- Support for Flutter v3.13.6.

## 0.3.0

- **BREAKING:** Deleted `CodeController.stringMap`.
- **BREAKING:** Deleted `theme` from `CodeController`, (Issue [172](https://github.com/akvelon/flutter-code-editor/issues/172)).

## 0.2.24

- Hide the suggestion box when `CodeField` is disposed (Issue [241](https://github.com/akvelon/flutter-code-editor/issues/241)).
- Fix issues with Flutter 3.10.

## 0.2.23

- Added `CodeController.readOnly`.

## 0.2.22

- Fixed most of the search bugs (Issue [228](https://github.com/akvelon/flutter-code-editor/issues/228)).

## 0.2.21

- 'Enter' key in the search pattern input scrolls to the next match.

## 0.2.20

- Alpha version of search.

## 0.2.19

- Fixed inability to change the value with `WidgetTester.enterText()` (Issue [232](https://github.com/akvelon/flutter-code-editor/issues/232)).

## 0.2.18

- Fixed the suggestion box horizontal offset (Issue [224](https://github.com/akvelon/flutter-code-editor/issues/224)).

## 0.2.17

- Allow to disable autocompletion (Issue [206](https://github.com/akvelon/flutter-code-editor/issues/206)).
- Close suggestions with Escape key (Issue [219](https://github.com/akvelon/flutter-code-editor/issues/219)).

## 0.2.16

- Do not delete folded blocks by backspace or delete keys (Issue [210](https://github.com/akvelon/flutter-code-editor/issues/210)).
- Use theme colors in error message overlays (Issue [212](https://github.com/akvelon/flutter-code-editor/issues/212)).

## 0.2.15

- Suggestion box is shown in an `OverlayEntry` instead of `Stack` (Issue [207](https://github.com/akvelon/flutter-code-editor/issues/207)).

## 0.2.14

- Fixed "Field 'windowSize' has not been initialized" bug (Issue [203](https://github.com/akvelon/flutter-code-editor/issues/203)).

## 0.2.13

- Workaround to disable spellcheck in Firefox (Issue [197](https://github.com/akvelon/flutter-code-editor/issues/197)).

## 0.2.12

- Fix undo/redo bugs (Issues [132](https://github.com/akvelon/flutter-code-editor/issues/132), [186](https://github.com/akvelon/flutter-code-editor/issues/186), [193](https://github.com/akvelon/flutter-code-editor/issues/193)).
- Fix cursor jumping bug ([Issue 182](https://github.com/akvelon/flutter-code-editor/issues/182)).

## 0.2.10

- Added pluggable analyzers support ([Issue 139](https://github.com/akvelon/flutter-code-editor/issues/139)).
- Added `DartPadAnalyzer`.
- Fixed linter issues ([Issue 164](https://github.com/akvelon/flutter-code-editor/issues/164)).

## 0.2.9

- Hiding line numbers, errors, and folding handles ([Issue 159](https://github.com/akvelon/flutter-code-editor/issues/159)).
- Indent new line after `:` in Python ([Issue 135](https://github.com/akvelon/flutter-code-editor/issues/135)).
- Track the test coverage, add the codecov badge ([Issue 146](https://github.com/akvelon/flutter-code-editor/issues/146)).
- Do not pale the editor if a visible section is set ([Issue 153](https://github.com/akvelon/flutter-code-editor/pull/153)).
- Added GIFs to README ([Issue 148](https://github.com/akvelon/flutter-code-editor/issues/148)).
- Fixed 'Index out of range' exception with visible sections on the default factorial example ([Issue 152](https://github.com/akvelon/flutter-code-editor/issues/152)).
- Fixed linter issues ([Issue 147](https://github.com/akvelon/flutter-code-editor/issues/147)).

## 0.2.8

- Java fallback parser preserves foldable blocks if `highlight` fails ([Issue 48](https://github.com/akvelon/flutter-code-editor/issues/48)).

## 0.2.7

- Fix joining nested foldable blocks ([Issue 136](https://github.com/akvelon/flutter-code-editor/issues/136)).

## 0.2.6

- Comment out and uncomment code with Ctrl-/ ([Issue 117](https://github.com/akvelon/flutter-code-editor/issues/117)).

## 0.2.5

- Tab and Shift-Tab handling ([Issue 116](https://github.com/akvelon/flutter-code-editor/issues/116)).
- Selection does not reset redo history ([Issue 133](https://github.com/akvelon/flutter-code-editor/issues/133)).

## 0.2.4

- Exported `StringExtension`.
- Added an example with changing the language and the theme.

## 0.2.3

- Fixed removing listeners in `_CodeFieldState.dispose()`.

## 0.2.2

- Added `CodeController.lastTextSpan` field (visible for testing) to return the last `TextSpan`
  produced by `buildTextSpan()`.

## 0.2.1

- Added the migration guide for 0.2 to README.

## 0.2.0

- **BREAKING:** Removed theme from `CodeController`. Use `CodeTheme` widget instead.
- **BREAKING:** Removed `webSpaceFix`, https://github.com/flutter/flutter/issues/77929
- **BREAKING:** Fixed typo `IntendModifier` → `IndentModifier`.
- **BREAKING:** `CodeFieldState` is now private.

## 0.1.15

- Added a missing code file.

## 0.1.14

- Python fallback parser preserves foldable blocks if `highlight` fails ([Issue 49](https://github.com/akvelon/flutter-code-editor/issues/49)).

## 0.1.13

- Remove an accidentally published temp file.

## 0.1.12

- Reformatted the license, updated README.

## 0.1.11

- Updated README.

## 0.1.10

- Fixed formatting.

## 0.1.9

- Read-only blocks are now pale ([Issue 103](https://github.com/akvelon/flutter-code-editor/issues/103)).

## 0.1.8

- Fixed linter issues.

## 0.1.7

- Fixed README errors.

## 0.1.6

- Improved README.

## 0.1.5

- Updated license formatting to match pub.dev requirements.

## 0.1.4

- Added `CodeController.readOnlySectionNames` getter and setter ([Issue 110](https://github.com/akvelon/flutter-code-editor/issues/110)).
- Added `CodeController.foldCommentAtLineZero`, `foldImports`, `foldOutsideSections` ([Issue 89](https://github.com/akvelon/flutter-code-editor/issues/89)).
- Added `CodeController.visibleSectionNames` ([Issue 27](https://github.com/akvelon/flutter-code-editor/issues/27)).
- Fixed folding Python blocks with multiline `if` conditions ([Issue 108](https://github.com/akvelon/flutter-code-editor/issues/108)).
- Fixed folding duplicate blocks like `[{...}]` etc ([Issue 99](https://github.com/akvelon/flutter-code-editor/issues/99)).
- Fixed `cutLineIndexIfVisible` bug ([Issue 112](https://github.com/akvelon/flutter-code-editor/issues/112)).

## 0.1.3

- Custom undo/redo implementation ([Issue 97](https://github.com/akvelon/flutter-code-editor/issues/97)).
- Remove `FoldableBlock` duplicates ([Issue 99](https://github.com/akvelon/flutter-code-editor/issues/99)).
- Copy folded text ([Issue 24](https://github.com/akvelon/flutter-code-editor/issues/24)).

## 0.1.2

- Preserve selection when folding and unfolding ([Issue 81](https://github.com/akvelon/flutter-code-editor/issues/81)).

## 0.1.1

- Added code folding.
- Fixed editing around hidden text ranges.
- Updated dependencies.

## 0.1.0

- Highlights unterminated blocks for Java and Python.

## 0.0.9

- Forked https://github.com/BertrandBev/code_field
- Re-license under the Apache license, mention the original author as the original license required.
- Added hidden service comment support.
- Added read-only blocks support.
- Added autocomplete for keywords, already-in-the-editor words, and external dictionary.
