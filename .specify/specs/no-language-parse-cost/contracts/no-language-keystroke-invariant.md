# Contracts — the no-language keystroke pin (#111)

The package's public API is unchanged. What this feature pins is an invariant
across two collaborators, expressed here so a reviewer can check it without
reading the whole dependency tree.

## Invariant

> An absent or unresolvable language costs strictly less highlight work than a
> resolvable one, and the difference is large enough that a regression making
> them comparable fails the test suite.

## Callers and callees

### `CodeController._createCode` (caller)

`lib/src/code_field/code_controller.dart:1005-1016`

```dart
Code _createCode(String text) {
  return Code(
    text: text,
    language: language,
    highlighted: highlight.parse(text, language: _languageId),
    ...
  );
}
```

Guarantees relied upon:
- `_languageId` is `''` until `setLanguage` is called (line 97, assigned at 274).
- The call is unconditional — the controller never branches on the language.
- `language` is `null` in the same state, so `autocompleter.mode` is `null`
  (line 280) and the autocompleter contributes nothing to the keystroke.

### `highlight.parse` (callee)

`highlight-0.7.0/lib/src/highlight.dart:264-271`

```dart
var langMode = _languageMode = _getLanguage(language) ?? plaintext;
```

Guarantees relied upon:
- `_getLanguage(name)` returns `null` for a name that is neither a registered
  language nor a registered alias (`highlight-0.7.0/lib/src/highlight.dart:497-501`).
- `plaintext` is `Mode(refs: {}, disableAutodetect: true)`
  (`highlight-0.7.0/lib/languages/plaintext.dart:6`) — an empty mode.
- An empty mode produces no tokens: no keywords to match, no sub-modes to push,
  no auto-detection to attempt.

## Consequences the pin depends on

1. The no-language parse cost grows *only* with document length (one walk, one
   text node), while the with-language parse cost grows with document length
   *and* with the mode's complexity.
2. Therefore the ratio no-language / with-language is bounded well below 1 by
   the mode's own size, not by machine speed.
3. A change that makes the no-language path do token-level work — for example
   a fallback to auto-detection, or registering a real language under the empty
   name — pushes the ratio toward 1 and reddens the suite.

## What is deliberately *not* part of the contract

- An absolute millisecond budget for either path. Machine-dependent; see
  `research.md` Decision 2.
- A guarantee that `highlight.parse` is skipped. It is not, and skipping it is
  not required (spec Assumptions). The invariant is about the *cost*, not the
  *call*.
