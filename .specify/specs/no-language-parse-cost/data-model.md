# Data Model — no-language keystroke cost (#111)

This feature introduces no new types, persistence, or API. The data model
below is the model the measurement test reasons about, documented so the test's
assertions can be traced to it.

## Entities

### Language fallback

What `CodeController` does when no language has been configured. This is where
the issue's premise is decided.

| Field | Value | Source |
|---|---|---|
| `_languageId` | `''` | `lib/src/code_field/code_controller.dart:97`, assigned only in `setLanguage` (line 274) |
| `language` | `null` until `setLanguage` | `lib/src/code_field/code_controller.dart:172` |
| `autocompleter.mode` | `null` | `lib/src/code_field/code_controller.dart:280` |
| resolved mode in `highlight` | `plaintext` | `highlight-0.7.0/lib/src/highlight.dart:271` |

**Validation rule**: a language name that does not resolve (an unregistered
alias) MUST behave identically to no language at all — FR-003. Both reach
`_getLanguage(name) == null` and therefore the same `plaintext` fallback.

### Keystroke path

The synchronous work driven by one edit, measured as a whole and attributed
per term (the decomposition recorded in
`test/src/code_field/edit_latency_test.dart:12-19` for a 3000-line document
*with* java):

| Term | With `java` (3000 lines) | No language (4800 lines, measured) |
|---|---|---|
| `highlight.parse(text)` | ~62% | 3.0 ms — ~7% of the whole keystroke |
| `Code(...)` construction | ~18% | unchanged (document-shaped, not language-shaped) |
| `Autocompleter.setText` | ~7% | skipped (`mode` is null) |
| remainder (edit diff, folds, hidden ranges, spans) | ~13% | dominates the no-language keystroke |

The parse term is the only one the feature's premise targets, and it is the one
that is already trivial when no language is set.

## State transitions

None. The feature adds no state and changes no lifecycle. `CodeController`'s
existing transitions (`setLanguage` → `_languageId` changes → every later
`_createCode` uses the new id) are the only relevant behaviour, and the
measurement test observes the state *before* any transition.

## Relationships

```text
CodeController
  └── _createCode(text)            lib/src/code_field/code_controller.dart:1005
        └── highlight.parse(text, language: _languageId)        :1013
              └── _getLanguage(_languageId) ?? plaintext        highlight-0.7.0
                    └── Mode(refs: {}, disableAutodetect: true) plaintext.dart:6
```

## Contracts

No external interface contract: the package's public surface
(`lib/zuraffa_code_editor.dart`) is unchanged by this feature. The contract the
test asserts is the *invariant* "an unresolvable language never costs more than
a resolvable one", which is a property of the `highlight` dependency's
fallback plus `CodeController`'s unconditional call — see `contracts/`.
