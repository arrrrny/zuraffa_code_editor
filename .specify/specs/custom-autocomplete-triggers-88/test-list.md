# Test list — custom autocomplete triggers (#88)

Derived from `.specify/specs/custom-autocomplete-triggers-88/spec.md`.
Engine: raw flutter commands (`.specify/memory/tdd-profile.md`).
Behaviours are driven through a real `CodeField` + `CodeController` so the
text-change path (`set value` → `generateSuggestions`) is the one under test,
not a stubbed entry point.

## Acceptance behaviours

| id | behaviour | kind |
|---|---|---|
| A1 | a registered trigger shows its callback's suggestions when typed | acceptance |
| A2 | a callback may be synchronous or asynchronous, with the same result | acceptance |
| A3 | the callback narrows the list as more of the trigger is typed | acceptance |
| A4 | a non-matching callback result hides the popup | acceptance |
| A5 | two triggers register; each arms on its own string | acceptance |
| A6 | when two triggers could match, the first registered wins | acceptance |
| A7 | the keyword completer is unchanged when no trigger is registered | default path |
| A8 | an armed trigger owns the list and the keyword words do not appear | acceptance |
| A9 | committing a suggestion with an empty prefix inserts the word | acceptance |
| A10 | committing a suggestion with a non-empty prefix replaces the prefix | acceptance |
| A11 | the commit does not re-arm the trigger that produced it | acceptance |
| A12 | a selection-only change clears the one-shot, so the next keystroke arms | acceptance |

## Inner behaviours

| id | behaviour | kind |
|---|---|---|
| U1 | the *last* occurrence of the trigger before the caret is the one that arms | unit |
| U2 | a trigger on an earlier line does not arm a caret below it | unit |
| U3 | no caret (`TextSelection.invalid`) arms nothing and does not throw | unit |
| U4 | a trigger whose text is still being typed arms nothing | unit |
| U5 | an empty trigger list is a no-op, not a regression of the keyword path | unit |

## Already covered elsewhere

- `popupController.show` / `hide` / selection / scroll — `test/src/wip/autocomplete/*`.
- Accept by tap, by arrow+Enter, and by tab — `test/src/code_field/{tap,tab}_accepts_suggestion_test.dart`.
- `Autocompleter` keyword, text, custom-word and blacklist behaviour — `test/src/autocomplete/autocompleter_test.dart`.

## Non-behaviour work

- `lib/src/autocomplete/custom_autocomplete_trigger.dart` — the public type
  (carries its own dartdoc; behaviour lives in `CodeController`).
- `README.md` — a section showing the registration and the arming rule.
- `.specify/feature.json` — pin to this directory.

## Coverage obligation

Every line added under `lib/` must be exercised by a behaviour above or an
existing test: the scanner (all its outcomes), the show/hide helper (both
branches), the accept path (armed and unarmed), and the one-shot flag (set,
consumed, cleared). `tool/coverage_gate.py --min 100` must report 100%.
