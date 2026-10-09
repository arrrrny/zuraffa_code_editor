# Bug Assessment: Reusing a RegExp causes a JavaScript error on web

- **Slug**: regexp-reuse-js-error
- **Issue**: 24
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/24
- **Assessed**: 2026-10-09
- **Verdict**: valid — residual hazard remains in a different file than the reported one

## Reproduction summary

Web only (Flutter 3.0/3.3, CanvasKit/web-html): pressing Enter after clicking a
method name moves the cursor to the bottom and appends an empty line. The IDE
debug output shows `JSNoSuchMethodError` thrown inside
`TextInputClient.updateEditingState`, with the Dart stack ending in
`autocompleter.dart:_updateText` → `RegExp.split` → `regExpCaptureCount`.
Not reproducible on Linux desktop.

## Root cause

The shared `static final RegExps.wordSplit` instance is passed directly to
`String.split`. Under dart2js a reused `RegExp` carries `lastIndex` state
between calls; the next engine call reads a null match group and throws,
corrupting the editing state.

## Current state on this fork

- `lib/src/autocomplete/autocompleter.dart:107-108` — the reported call site is
  already fixed: the direct `.split(RegExps.wordSplit)` is commented out and
  the active line uses `.split(RegExp(RegExps.wordSplit.pattern))`. The fix
  upstream shipped for this issue is present here.
- `lib/src/code_field/text_editing_value.dart:51,53` — **not fixed**:
  `text.lastIndexOf(RegExps.wordSplit, cursorPosition - 1)` and
  `text.indexOf(RegExps.wordSplit, cursorPosition)` still hand the shared
  instance to the engine on every cursor move (wordAtCursor / wordToCursor /
  wordAtCursorStart). That is the same hazard class the issue reports, one
  file over, in code that runs constantly while typing on web.

## Proposed fix

Construct a fresh `RegExp` from the pattern at both call sites in
`_getWordAtCursorStartEnd()` (a private static or a local), matching the form
already used by `autocompleter.dart`. Zero behavior change on the VM; removes
the web hazard class from the remaining sites.

## Verification plan

- Unit tests pin `wordAtCursor`, `wordToCursor`, `wordAtCursorStart` results
  across repeated calls in one test (a shared, stateful RegExp would produce a
  wrong second result on web).
- Mutation check: routing the calls back through the shared `RegExps.wordSplit`
  instance must not change VM behavior — so additionally assert on the
  source-level seam: extract the pattern into a fresh-instance helper and test
  the helper directly for reuse safety (two calls on the same text give the
  same answer).

## Severity / effort

- Severity: low (web-only; the reported crash site is already fixed; remaining
  sites are latent, not yet reported as failing).
- Effort: small — two call sites, no API change.
