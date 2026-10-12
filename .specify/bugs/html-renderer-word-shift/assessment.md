# Assessment: html-renderer-word-shift-110

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/110
(upstream akvelon/flutter-code-editor#68).

- **Verdict**: renderer-level defect, reachable only through the documented
  tab opt-out — no package-side code change recommended.

## Mechanism (from the upstream reproduction steps)

The report's first step is "disable `TabModifier`". In this package that is
load-bearing in two places:

- `CodeController._isTabReplacementEnabled` is derived as
  `modifiers.any((e) => e is TabModifier)` (`code_controller.dart:186`), so
  removing `TabModifier` also disables the tab→spaces conversion in the `value`
  setter.
- A raw `U+0009` then survives into `TextEditingValue.text` and into the
  rendered spans.

A tab has no glyph of its own: each engine lays it out with its own rule. The
VM text engine advances to the next tab stop of the font metrics; the HTML
renderer routes the text through the DOM, where `U+0009` is whitespace and
advances by the browser's tab stops (commonly every 8 columns). Every keystroke
re-measures with one more tab, so the text after each tab lands a different
distance right — the "words shift chaotically" symptom, and the reason it does
not reproduce on desktop. Flutter's own tab-rendering defect
(flutter/flutter#79153) is the same family; upstream marked the issue blocked.

## What was measured here

- **The default configuration cannot reach it.** `defaultCodeModifiers`
  contains `TabModifier`, so both conversion sites (load and edit) are on and
  no tab ever reaches the text. Pinned by the `Tab never survives into the code
  (#20)` group in `test/src/code_field/tab_tofu_canvaskit_test.dart` (load,
  platform value update, composing, composing while folded) and
  `test/src/code_field/code_controller_tab_test.dart` (load, custom
  `tabSpaces`, several insertions).
- **The opt-out is documented and pinned, not accidental.**
  `tab_tofu_canvaskit_test.dart` pins `Without TabModifier the tabs are left to
  the consumer`, and the `tab-tofu-canvaskit` record states the contract: a
  consumer that removes `TabModifier` owns tab handling. Feeding the editor
  document text containing tabs is the consumer's call.
- **The `highlight` HTML mode is not a trigger.** Driven a real HTML document
  through `CodeController(language: xml)` — the mode `html` aliases — and
  walked the highlight node tree: 48 nodes, every word whole (`Hello`,
  `Some paragraph text here`, `main`, `a comment` each arrive as one node);
  node boundaries land on token edges only. A hypothetical highlight release
  that started splitting words inside a styled run could shift words on the
  HTML renderer through span boundaries, but that is not what the mode does
  today.

## Recommended direction

No code change. The package-side guarantee that bounds the defect (tabs never
reach the text under the default configuration) is already pinned, and the
remaining path is the documented consumer opt-out. What would sharpen the
record is a browser observation of the exact advance the HTML renderer gives a
tab — that needs the example app served with `--web-renderer html`, which this
environment does not have; the assessment labels the mechanism from the
reproduction steps rather than measuring pixels.
