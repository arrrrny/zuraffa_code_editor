# Migration Plan: zuraffa_code_editor → re_editor

**Status:** implemented on `009-re-editor-migration`. Backward compatibility was
explicitly NOT a concern — this package is new and the public API changed
freely. The breaking changes are listed in §8.

## 1. Why migrate

The editor was built on Flutter's `TextField`/`EditableText`, which lays out
and paints the **entire document as a single paragraph** on every frame. Every
keystroke re-measures the whole text, so editing large files (>\~5k lines) is
O(n) per keystroke and visibly laggy.

`re_editor` (Reqable, production-tested) renders **line-by-line in a
virtualized scroll view**, so only visible lines are laid out and painted.

`code_forge` was also evaluated. It claims better performance (rope data
structure + `RenderBox`/`ParagraphBuilder`) and ships LSP/AI, but it is
heavier, web/stdio-LSP oriented, and its dependency surface
(`re_highlight` + LSP client) is much larger than this package needs. For
an editor that only needs syntax highlighting + folding + autocomplete +
search, `re_editor` is the better fit and is the one used in production by
Reqable. `code_forge` remains an option if LSP/AI is wanted later.

## 2. The bottleneck was not only the text field

The premise the migration started from — "the `TextField` is slow" — was
only half true. Profiling the 50 000-line document found a second, larger
cost that had nothing to do with layout:

`CodeController` ran a **whole-document `package:highlight` parse on every
text change**, and that parse is **quadratic**. `highlight` 0.7.0 merges the
text of a whole unmatched stretch into one node and copies the string merged
so far on every merge (`mode_buffer += buffer` in `_processLexeme`,
`result.last.value = result.last.value! + node.value!` in `_addNodes`). A
document whose top-level terminator regex matches rarely — which is what
real code looks like — puts the whole document in one buffer, and the cost
is O(n²).

Measured on the 50 000-line playground document:

| | before | after |
|---|---|---|
| `CodeController` construction | 47 000 ms | 743 ms |
| one-character edit | 58 725 ms | 1 223 ms |

The fix is `CodeController.highlightEnabled`, **off by default**. The
re_editor renderer highlights the code itself (with `re_highlight`, in an
isolate, with its own size guard), so the package's own parse is only needed
by the text field renderer, which turns the flag on while it is mounted. With
the flag off, the folding and the service comments are found in the raw text
by text-based parsers instead (`FoldableBlockParserFactory.provideTextParser`).

## 3. Goal

Replace the `TextField`-based rendering core with `re_editor` while keeping
the public `CodeField`/`CodeController` ergonomics that the playground
(`dws_playground`) and tests depend on, and preserving the features that
make this package distinct: folding with visible closing lines, named
sections, hidden line ranges, autocomplete, search, themes, gutter.

## 4. Component mapping

| Current (this package) | re_editor equivalent | Work |
|---|---|---|
| `CodeField` (TextField + gutter + background layer) | `CodeEditor` (line-virtualized) + custom gutter | Done: `CodeFieldRe` + `CodeGutter` |
| `CodeController` (extends `TextEditingController`) | `CodeLineEditingController` (re_editor) | Done: `ReEditorCodeController` bridge; the package's controller keeps the document, the folds and the history |
| Folding (`foldable_block`, `hiddenLineRanges`) | text-based foldable block parsers | Done: the block detection stays in the package, the re_editor side only sees the visible text |
| Named sections / hidden ranges | visible text | Done: the bridge renders `controller.text`, the text with the hidden ranges cut out |
| Autocomplete (`Autocompleter`, popup) | re_editor's own editable + the package's popup | Done: the package's suggestion list and popup, positioned at the caret |
| Search (`SearchController`, `SearchWidget`) | `CodeFindController` | Done: re_editor paints the matches, the package's controller counts and navigates them |
| Highlighting (`package:highlight`) | `re_highlight` | Done: `ReHighlightModeConverter` |
| Themes (`CodeTheme`/`CodeThemeData`) | `CodeEditorStyle.codeTheme` | Done: `buildReHighlightTheme` |
| Gutter (`GutterWidget`) | `indicatorBuilder` | Done: `CodeGutter` draws the rows re_editor has laid out |
| History (`CodeHistoryController`) | re_editor's undo/redo | Done: the package's history stays; re_editor's undo intent is overridden to call it |
| Actions (indent/outdent/tab/enter/comment) | re_editor's shortcuts | Done: `shortcutOverrideActions` routes the intents to the package's actions |
| Copy and cut | re_editor's clipboard actions | Done: overridden with the package's own, so a fold's hidden lines are copied with the selection |
| RTL text direction | — | **Delegated to the text field renderer** (see §6) |
| JS web workarounds | re_editor handles web | Kept; they are harmless |

## 5. Phases — what was built

1. **Spike.** `re_editor` 0.10.0 and `re_highlight` 0.0.3 added; the 50k-line
   document rendered and edited.
2. **Core controller.** `ReEditorCodeController` bridges the package's
   `CodeController` and re_editor's line controller: the visible text goes
   out, the edits come back and are mapped onto the full text by
   `LinePositionMapper`, so a fold's hidden lines survive an edit.
3. **Rendering.** `CodeFieldRe` draws the code with `CodeEditor`; `CodeGutter`
   draws the line numbers, the fold chevrons and the error markers next to
   the rows re_editor has laid out.
4. **Highlighting & themes.** `ReHighlightModeConverter` converts a
   `package:highlight` grammar into a `re_highlight` one (the scope moves
   from the deprecated `className` to `scope`); `buildReHighlightTheme` maps
   the package's `CodeTheme` onto re_highlight's theme.
5. **Folding.** The package's own foldable block detection is kept — it is
   what makes the *visible closing line* possible — and the re_editor side
   only ever sees the folded text.
6. **Autocomplete & search.** Re-wired; re_editor's own key bindings are
   overridden so the package's semantics win.
7. **Tests.** The suite was migrated: the tests that drive the caret with the
   text field's own keyboard semantics are pinned to the text field renderer
   (`test/src/common/create_app.dart` takes a `renderer`), and the re path
   has its own tests (`code_field_re_*`).
8. **Playground.** `dws_playground` uses the re_editor renderer through its
   path dependency; `test/code_editor_large_document_test.dart` is the
   50 000-line check.
9. **Release.** Version bump, changelog and this document.

## 6. What re_editor cannot do, and what was done about it

- **RTL.** re_editor 0.10.0 hardcodes `TextDirection.ltr`: the paragraph
  style (`_code_paragraph.dart:215`), the text painter
  (`_code_paragraph.dart:225`), the field (`_code_field.dart:1185`) and the
  indicator (`_code_indicator.dart:30`). `CodeEditorStyle` has no
  `textDirection`. So `CodeField` **falls back to the text field renderer
  whenever the resolved direction is RTL** — right to left stays functional,
  and left to right is the fast path. Forking re_editor is out of scope.
- **The fold marker.** The text field renderer draws ` …` at the end of a
  folded block's kept line. The re path does not: the marker would have to
  be injected into the visible text, which shifts every offset the bridge
  maps through it. The chevron in the gutter is the re path's affordance.
- **Per-line `lineBackgroundBuilder`.** The text field renderer paints it
  behind the text; re_editor has no per-line background hook, only
  `cursorLineColor`, which is wired. Not ported.
- **The mobile platforms keep re_editor's own enter key.** re_editor decides
  between a mobile and a desktop build of the editor from its own
  `kIsAndroid` (`re_editor-0.10.0/lib/src/_consts.dart:4`), and the two are
  not the same: the desktop one installs a `Shortcuts` layer, which is what
  the package's overriding actions plug into, while the mobile one handles
  the enter key in the editor's own focus node, before any shortcut of the
  package's can see it. So on Android and iOS the enter key breaks the line
  instead of committing the suggestion or moving to the next search match.
  Every other key — the tab key, the undo keys, the comment key, the find
  key — keeps the package's semantics on both. Forking re_editor to get the
  last key is out of scope, the same way the RTL fallback is.

## 7. Risks, and how they were met

- **Folding semantics.** The "visible closing line" behaviour and the
  `code.text` vs visible text distinction are preserved exactly: the bridge
  renders `controller.text`, the text with the folded blocks and the hidden
  ranges cut out, and the edits are mapped back onto the full text.
- **Highlighting API differences.** `re_highlight`'s `Mode` differs from
  `highlight`'s; the converter carries every field over, and the embedded
  sub-languages are re-tested.
- **Test churn.** 169 test files; the ones that assert on `TextField`
  internals are pinned to the text field renderer.
- **Performance claims.** Measured, not assumed: the numbers are in §2.

## 8. Breaking changes

- `CodeField` renders with `re_editor` by default. The text field renderer
  is still there, as `renderer: CodeFieldRenderer.textField`.
- `CodeController` gained `highlightEnabled` (off by default) and
  `isDisposed`.
- A field whose direction is right to left is drawn with the text field
  renderer.
