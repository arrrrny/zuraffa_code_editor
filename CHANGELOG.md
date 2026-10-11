# Changelog

## Unreleased

### Added

- **The cost of an unhighlighted editor is pinned by a test**
  ([issue #111](https://github.com/arrrrny/zuraffa_code_editor/issues/111) and
  [issue #93](https://github.com/arrrrny/zuraffa_code_editor/issues/93),
  upstream `akvelon/flutter-code-editor#246`). `CodeController` calls
  `highlight.parse` on every edit whether or not a language is configured, and
  both reports read that as the cause of a ~20 s stall on a 4800-line document
  with no language selected. Measured, it is not: `highlight` 0.7.0 resolves an
  empty or unrecognised language name to `plaintext` — an empty mode with no
  keywords, no sub-modes and no auto-detection — so the highlight step costs
  10–18 µs against 78.9–96.5 ms with `java`, one keystroke medians 13–23 ms
  against 119.9–129.5 ms, and a paste of the whole document 16–23 ms against
  124.8–129.2 ms. Neither path approaches the reported stall, and skipping the parse
  would remove at most ~18 µs from a ~14 ms keystroke, so no code changed.
  `test/src/code_field/no_language_keystroke_test.dart` pins the conclusion as
  ratios between the two paths plus absolute bounds of 100 ms per keystroke and
  1 s per paste, and a fault injection that makes the no-language fallback
  resolve to a real language (parse 80 532 µs against the with-language
  76 120 µs, keystroke 109 045 µs, paste ratio 0.98) reddens it — so a future
  change that makes an unhighlighted editor expensive fails the suite instead of
  reaching users.

### Changed

- **The gutter stays on the code line grid at any code font size**
  ([issue #107](https://github.com/arrrrny/zuraffa_code_editor/issues/107),
  upstream `akvelon/flutter-code-editor#312` and `#215`). The gutter lays its
  rows out in a `Table`, whose row height is the tallest cell in it. The number
  is one code line tall, but the two fixed icon columns always rendered their
  glyph at 16px, so whenever the code's line box was shorter than 16 the icon
  set the row's height instead: the row pitch exceeded the code line height by
  the overshoot and the gutter separated from the code by that much again on
  every line below. The reported configurations never reach the case — `height:
  1.5` at `fontSize: 16` and `18` gives a 24-27px line box, and so does the
  `fontSize: 13, height: 1.6` the existing grid pins use — which is why those
  pins pass while the drift is real. Measured on master at `height: 1.0`, the
  pitch ran 10.500 against a 9px line box at `fontSize: 9` (10.5px of drift by
  the last row) and 13.643 against 13px at `fontSize: 13` (4.5px). Both icon
  glyphs are now clamped to the code line height, which is a no-op above a 16px
  line box, so every rendering that already fits is byte-identical — only the
  column widths were fixed before and only the glyph now shrinks.
  `test/src/gutter/gutter_icon_row_height_test.dart` pins the invariant across
  the whole sub-16 range, and all three fault-detecting tests are red without
  the fix (`Expected <30.5> Actual <32.0>`, the pitch of two stacked 16px
  glyph boxes).

- **The code area's horizontal scroll is pinned on both of its paths**
  ([issue #85](https://github.com/arrrrny/zuraffa_code_editor/issues/85),
  upstream `akvelon/flutter-code-editor#280`, reported as "horizontal scrolling
  does not work on iOS, works on Android"). Measured, the platform claim is the
  wrong way round: on a 240 px drag over the code text the code area scrolls
  0 → 201 px under an iOS platform override and stays at 0 under an android one.
  The split is Flutter's, not this package's — `TextField` registers a
  `TapAndHorizontalDragGestureRecognizer` whose `eagerVictoryOnDrag` is
  `defaultTargetPlatform != TargetPlatform.iOS`, and being deeper in the hit-test
  tree than the code area's `SingleChildScrollView` it enters the gesture arena
  first and, on non-Apple platforms, claims the drag for text selection. Nothing
  in `lib/` changed and no behaviour is new: the caret reveal already works on
  every platform and is pinned with it, and the drag split is now pinned so a
  Flutter upgrade that flips `eagerVictoryOnDrag` fails the suite instead of
  silently changing who wins the drag. The correct follow-up — an interactive
  horizontal `Scrollbar`, whose thumb drag uses its own recognizer deeper than the
  `TextField`'s and so wins the same arena without touching selection — is
  recorded in `.specify/bugs/ios-horizontal-scroll-85/assessment.md`.
- **A single tap commits an autocomplete suggestion, and the popup stays inside
  the window** ([issue #84](https://github.com/arrrrny/zuraffa_code_editor/issues/84),
  upstream `akvelon/flutter-code-editor#205`). On mobile the suggestion popup
  needed a double tap and was cut off, because `Popup`'s row had the commit on
  its `onDoubleTap` — so the gesture arena held the first tap back until the
  double tap timeout — and the popup was placed against the *editor's* render
  box while it actually renders in the full-screen overlay: the horizontal clamp
  subtracted an unexplained 100 px, which put the popup off the left edge of any
  editor narrower than 400 px, and the vertical flip was refused outright when
  the editor was shorter than the popup's maximum height. A tap now commits the
  word on its row exactly as Enter does, the popup is clamped into the window it
  is measured against — the real window, which `CodeField` now hands it instead
  of its own box — and the flip is decided by the height the suggestions
  actually need, capped at the popup's maximum height.
- **A visible section renders flush with its contents** ([issue #35](https://github.com/arrrrny/zuraffa_code_editor/issues/35),
  upstream `akvelon/flutter-code-editor#109`). A section whose `[START name]`
  and `[END name]` tags sit on lines of their own used to present a blank line
  before and after its contents — the shell of each tag line, the whitespace
  before the comment and the line break after it — and the gutter carried a
  number for both. Those two lines are now cut whole, so the presented section
  starts and ends with its own code. A tag that shares its line with code
  (`class A {// [START s]`) keeps its line, because the code before the comment
  belongs to the section; a section with no start tag cuts its end tag alone;
  and a document with no visible section is byte-for-byte unchanged.

### Added

- **The gutter's error icon is overridable, by issue type**
  ([issue #81](https://github.com/arrrrny/zuraffa_code_editor/issues/81),
  upstream `akvelon/flutter-code-editor#216`). The gutter rendered one
  hardcoded red `Icons.cancel` for every issue and offered no way to change it.
  `GutterStyle` now carries `errorIcon`, `warningIcon` and `infoIcon` — nullable
  `IconData`s resolved per issue through `GutterStyle.issueIcon(IssueType)` — and
  `GutterErrorWidget` takes an optional `icon` widget for a host that mounts it
  directly. A style that sets none of them renders exactly the icon it always
  did: every type still falls back to `defaultIssueIcon`, which is the glyph the
  `errorIcon` constant is now built from so the two cannot drift apart. Only the
  glyph is overridable — the icon is drawn at the issue column's own width, so
  its size stays part of the row geometry.
- **The gutter error popup's decoration is overridable**
  ([issue #82](https://github.com/arrrrny/zuraffa_code_editor/issues/82),
  upstream `akvelon/flutter-code-editor#217`). The popup's container chrome was
  derived inline from the popup text style's `backgroundColor` and `color`, which
  meant those two `TextStyle` fields were load-bearing for something that is not
  text styling and there was no way to set a shape or a border.
  `GutterStyle.errorPopupDecoration` now supplies the `BoxDecoration` outright,
  and `GutterErrorWidget.popupDecoration` does the same for a host that mounts
  the widget directly. Leaving it null keeps the existing derivation exactly,
  and the popup's content — message, url, suggestion and divider — is untouched
  either way. A `popupBuilder` that would replace the whole overlay is
  deliberately not in this change.
- **Tab, Shift+Tab and Enter are dispatched through Flutter's `Shortcuts` /
  `Actions` machinery**, and the raw key path is now pinned as owning none of
  them ([issue #29](https://github.com/arrrrny/zuraffa_code_editor/issues/29)):
  `CodeField`'s `FocusableActionDetector` sends Tab to `TabKeyIntent`, Shift+Tab
  to `OutdentIntent`, Enter to `EnterKeyIntent`, Ctrl+/ to
  `CommentUncommentIntent` and Ctrl+F to `SearchIntent`, and
  `CodeController.actions` answers each with its action;
  `CodeController.onKey` handles only Ctrl+F and the autocomplete popup's arrows
  and returns `ignored` for everything else. The negative is what
  `test/src/code_field/tab_through_shortcuts_test.dart` pins — a regression that
  moved Tab back into a raw handler would leave every behavioural test green,
  because the observable effect of a Tab is identical either way.
- **Outdent on Backspace, and a modifier hook that can carry it**
  ([issue #21](https://github.com/arrrrny/zuraffa_code_editor/issues/21)):
  pressing Backspace inside a line's leading whitespace now removes one indent
  level instead of one space, and the modifier that does it is shipped in
  `CodeController.defaultCodeModifiers`. Supplying your own `modifiers` list
  without `OutdentModifier` keeps the plain one-character delete.

  This needed a new hook, because the one the reporter reached for cannot work:
  a `CodeModifier` is keyed on the character that was **typed**, and a backspace
  removes a character rather than inserting one, so no key was ever produced and
  no modifier — on any character — could fire. `CodeModifier` now takes an
  optional `deletesChar`, and `CodeController` keeps a second map for those
  modifiers, keyed on the character that was removed. The dispatch is guarded by
  a single-character collapsed deletion, and a backspace over real code is still
  a one-character delete: the modifier declines any line whose leading run is not
  all spaces. A deletion cannot cross a read-only range or a folded block either
  — the modifier's result is folded into the value before those guards run.
- **Web is a genuinely supported platform**
  ([issue #23](https://github.com/arrrrny/zuraffa_code_editor/issues/23)):
  `autotrie`, the one dependency in the graph that reported no `platform:web`,
  is replaced by an in-house engine at
  `lib/src/autocomplete/auto_complete.dart`. `autotrie`'s only entry point
  re-exports `src/autotrie_base.dart`, whose first line is `import 'dart:io'`,
  and `dart:io` has no web implementation — that single import is why pub.dev
  listed `android, ios, linux, macos, windows` and not `web`, and why a web
  build of anything reaching the autocompleter failed to compile. The two
  methods that need it, `AutoComplete.fromFile` and `AutoComplete.persist`,
  are file-persistence helpers with no caller in this package, so the port
  carries the in-memory surface only and `hive` leaves the graph with
  `autotrie`. Pinned by `test/src/autocomplete/auto_complete_test.dart`
  (36 tests); the port corrects two `autotrie` defects that cannot be fixed
  upstream, both unreachable from `Autocompleter`: `contains` now reports
  entered words rather than surviving prefix paths, and `delete` now clears the
  hit of the word it removes instead of leaving it suggested when a longer word
  shares its prefix. `pubspec.yaml` now declares all six platforms explicitly,
  so the support cannot silently regress when a dependency that reaches
  `dart:io` is added.
- **Right-to-left text direction support**
  ([issue #14](https://github.com/arrrrny/zuraffa_code_editor/issues/14)):
  `CodeField` gained a `textDirection` parameter. Left null it resolves the
  ambient `Directionality`, so an Arabic locale already renders right to left
  with no configuration — text, caret movement, the gutter (which flips to the
  right edge with the text) and the platform's bidi reordering of mixed
  Latin/Arabic runs. Set it to force a direction for a right-to-left snippet
  inside a left-to-right app.

  The defect this fixes was in the measurement, not the rendering: every
  `TextPainter` the field builds hardcoded `TextDirection.ltr`, so in an RTL
  field the autocomplete popup was positioned where the caret *would* be if the
  text ran left to right — the far side of the editor. The resolved direction now
  reaches the `TextField` and the caret painter that positions the popup. The
  row-height painters stay `ltr` deliberately: a paragraph's direction moves
  text horizontally, never vertically. Pinned by
  `test/src/code_field/text_direction_test.dart`.

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
  In practice, `<script>` and `<style>` bodies stay markup rather than being
  re-parsed as JavaScript or CSS in `highlight` 0.7.0: the mode does declare
  `subLanguage` entries for both, but their `<script`/`<style` tag modes never
  match, so those entries never engage (`<?php ?>` bodies *are* parsed, as
  PHP). If a future `highlight` release fixes the matching, the bodies would
  start being re-parsed.

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

- **XML documents are foldable again**
  ([issue #103](https://github.com/arrrrny/zuraffa_code_editor/issues/103),
  upstream `akvelon/flutter-code-editor#311`, reported as "HTML/XML highlighting
  is broken"). The highlighting half of the report does not reproduce:
  `highlight.parse(src, language: 'xml')` classifies a document into `meta`,
  `comment` and `tag` nodes carrying `name`, `attr` and `string`, and driving
  `SpanBuilder` with `vsTheme` over those nodes paints them in six distinct
  colours, so the widget path is the same path and cannot differ. What does
  reproduce is the other half, "the document structure is lost":
  `CodeController(text: ..., language: xml).code.foldableBlocks` is empty, where
  java yields two brace blocks on `class A { void m() { } }`.
  `FoldableBlockParserFactory` special-cased python, java and yaml and sent
  everything else to `HighlightFoldableBlockParser`, which opens blocks on `(`,
  `[` and `{` only — and markup nests on `<tag>`/`</tag>`, so no bracket ever
  appears and no block is ever opened. Markup now has its own parser, driven by
  the highlight nodes rather than a text scan so a `<` inside a comment or an
  attribute string can never look like an element: nested elements produce
  nested `FoldableBlockType.markup` blocks, self-closing tags (`<br/>`,
  `<img src="x" />`) and the `<?xml ?>` declaration produce none, a
  `<a>text</a>` pair on one line produces none because `endBlock` already drops
  same-line blocks, and an unclosed element or a stray closing tag is reported
  as an `InvalidFoldableBlock` the way an unclosed brace is. The Android layout
  in `test/src/folding/parsers/markup_parser_test.dart` now folds its
  `LinearLayout` and `FrameLayout` instead of neither.

- **A `#` no longer costs a Java file its highlighting**
  ([issue #104](https://github.com/arrrrny/zuraffa_code_editor/issues/104),
  upstream `akvelon/flutter-code-editor#42`). `highlight` 0.7.0's `java` mode
  declares `illegal: "<\\/|#"`, and `_parse` treats an illegal lexeme as a
  silent bail — it throws, catches the throw itself and hands back the entire
  document as one unclassified node, so a single `#` outside a comment or a
  string literal (or a stray `</`) erased every class in the file. A
  triple-quoted string literal reached the same end by another route: with no
  triple-quote mode, the third `"` of `"""` opens an ordinary string whose
  content crosses a newline, and an ordinary `java` string declares a newline
  illegal. `CodeController` now registers a repaired copy of the `java` mode
  with the highlighter — the `illegal` regex dropped, a `"""`…`"""` string mode
  listed ahead of the single-quoted ones. It has to be a copy rather than the
  shipped mode with a field cleared, because `Mode` caches the regexes compiled
  from `illegal` and `contains` on the first parse, so a cleared field leaves
  the stale regexes in place and the defect alive. Only the highlight parse
  sees the copy: `controller.language` is still the mode the caller supplied,
  and every other language is registered exactly as it was given. Measured on
  master, both `public class A {\n}\n#\n` and
  `String s = """\nmultiline\n""";` came back as
  `Result(relevance: 0, nodes: [one node])`; after the repair the first
  classifies `public`, `class`, `title` and the second classifies the literal
  as one `string` run spanning all three lines. A raw newline inside an
  ordinary `"..."` still bails — a Java syntax error rather than a defect, and
  the other side of that trade has no clear winner — while
  `test/src/highlight/java_language_test.dart` pins the repaired
  classification and the unchanged one side by side.

- **Deleting a folded block's closer no longer destroys the block's content**
  ([issue #98](https://github.com/arrrrny/zuraffa_code_editor/issues/98),
  upstream `akvelon/flutter-code-editor#176`). Backspacing the `}` of a folded
  block — the first visible character after the block's hidden range —
  recovered the replaced range with downstream affinity, which expanded the
  range into the hidden content and spliced it out of the document along with
  the brace. An edit that begins where a folded block's hidden range collapses
  now recovers its start after the content, so only the removed characters are
  deleted: the brace goes, the body survives, and the block releases because
  there is no closer left to fold. The guard is keyed on what the edit removes,
  not on the direction the visible text's length moved, so replacing the
  closer with longer text (typing `} else {` over it) is protected too — a
  pure insertion at that point keeps the documented downstream recovery.
  Edits at any other hidden range — a named section's marker comment — are
  unchanged.

- **Folding a two-line block no longer deletes the line that starts the next
  one** ([issue #99](https://github.com/arrrrny/zuraffa_code_editor/issues/99),
  upstream `akvelon/flutter-code-editor#213`). When a block's closing line was
  also the opening line of the next block and only one content line separated
  them (`if (a &&` / `b) {`), the guard that gives the closer a row of its own
  had nothing to work with and the fold hid the shared line whole — taking the
  following block's first line, its line number and its fold toggle off the
  screen. The range now ends at the shared line's start instead, gluing it onto
  the opener's row: the same shape a leading closer (`}void main(){`) already
  folds to, and the most a two-line fold can offer, since a `HiddenRange`
  cannot be empty. Multi-line touching blocks keep their closer's own row, and
  a leading-closer two-line shape folds exactly as before.

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

- **The keystroke cost is measured, decomposed and pinned against super-linear
  growth** ([issue #22](https://github.com/arrrrny/zuraffa_code_editor/issues/22),
  upstream `akvelon/flutter-code-editor#264`). One single-character keystroke in
  a 3000-line document costs ~84 ms under `flutter test`, and it is
  `highlight.parse` of the whole document (~62%, 52–59 ms), the `Code(...)`
  construction (~18%, 15–18 ms), `Autocompleter.setText` (~7%, 5.6–6.7 ms) and
  the edit diff, tab replacement and selection mapping (~13%). Each of the
  three big terms is whole-document work, and none can be trimmed without an
  architectural change: the `highlight` package lexes from offset 0 on every
  call with no incremental API, `Code` is immutable and rebuilt wholesale, and
  the autocompleter's remaining `_splitWords` scans the full text. The issue
  asks for lazy loading; upstream declined it for the same reason ("you would
  have to mostly rewrite the entire text editor"), and the measurement here
  confirms it, so the deliverable is the number and a guard, not a rewrite. The
  guard is `test/src/code_field/edit_latency_test.dart`: the per-line keystroke
  cost at 3000 lines within 2× the per-line cost at 200 lines, tightened from
  3× after measuring the unmodified ratio at 1.01–1.25 over five runs. An
  injected O(rows²) pass in `CodeLinesBuilder.textToCodeLines` (+29 µs/line at
  3000 lines) reddens it at 2.13×; reverting either of #39's O(n) trims does
  not, which is the honest limit of a linearity bound and is recorded in the
  spec.

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
