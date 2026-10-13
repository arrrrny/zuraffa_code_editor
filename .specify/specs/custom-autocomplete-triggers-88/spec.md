# Custom autocomplete triggers (#88)

## What was asked

Upstream `akvelon/flutter-code-editor#220`: "Please provide an autocomplete
callback based on custom triggers". The reporter wants completion after ` >> `.
Today `CodeController`'s suggestion path is hardcoded: it asks
`CodeController.autocompleter` for words matching `value.wordToCursor`, and
`wordToCursor` (`text_editing_value.dart:74`) is the word at the caret split on
`RegExps.wordSplit` (`[^_a-zA-Z0-9]+`), so a trigger made of spaces and
punctuation can never produce a prefix. The only workaround the reporter found
was subclassing `CodeController` and overriding `generateSuggestions()`, which
breaks on internal changes and cannot narrow the list incrementally.

## Why it matters

Context-sensitive completion is the difference between a syntax highlighter and
an editor. `Autocompleter.setCustomWords` already lets a host widen *which*
words are suggested, but not *when* to ask or *what* to match — the trigger rule
itself is compiled in.

## Acceptance criteria (from the issue)

- [ ] A public API registers one or more triggers with a suggestion callback.
- [ ] The keyword completer keeps working unchanged when no trigger is
      registered.
- [ ] The callback can narrow the list as more of the trigger follows.
- [ ] Tests cover a registered trigger, narrowing, and the default path.

## Design

### The public type

`lib/src/autocomplete/custom_autocomplete_trigger.dart`:

```dart
class CustomAutocompleteTrigger {
  const CustomAutocompleteTrigger({
    required this.trigger,
    required this.getSuggestions,
  });

  /// The string that arms the trigger, e.g. `' >> '`.
  final String trigger;

  /// Called with the text typed after the arming trigger, up to the caret.
  final FutureOr<List<String>> Function(String prefix) getSuggestions;
}
```

A callback, not a word list: the host owns the source, so a remote index or a
computed set costs nothing to add. `FutureOr` keeps a synchronous provider
synchronous.

### Registration

`CodeController.customAutocompleteTriggers` — a `List`, default `const []`.
Replacing the whole list is the supported edit; the field is read on every
evaluation, so mutating it in place also takes effect.

### The arming rule

`_armedCustomTrigger()` scans the caret's **own line** only:

1. No caret (`selection.start < 0`, the field's first value round-trip carries
   `TextSelection.collapsed(offset: -1)`) → nothing is armed.
2. Otherwise take the caret's line up to the caret and, for each registered
   trigger in order, find its **last** occurrence in it.
3. The first trigger with an occurrence arms: the prefix is everything after it,
   and the **prefix start** is that occurrence's end.
4. No occurrence for any trigger → nothing is armed.

Taking the last occurrence is what makes step (3) mean "the text typed after the
trigger" rather than "everything since the trigger was first typed", and it lets
a prefix contain the trigger's own characters without confusing the scan.

The line bound is what keeps the prefix bounded. Without it a trigger typed on
line 1 still arms a caret on line 40 and hands the callback a prefix spanning
every character in between; each line is its own completion scope, which is how
every editor with trigger completion behaves.

### Precedence

An armed trigger **bypasses** the keyword completer for that evaluation: its
callback owns the list, and the blacklist is not applied to it (the blacklist is
the keyword path's `wordAtCursor` concern). When nothing is armed the existing
`wordToCursor` path runs, unchanged, including its empty-result hide.

### Committing

`insertSelectedWord()` already replaces `value.wordAtCursor` at
`value.wordAtCursorStart`. A trigger's prefix is not necessarily a word and can
be empty, so the accept path re-runs the same `_armedCustomTrigger()` and, when
one is armed, replaces from the recorded prefix start instead. Both call sites
use the same scan of the same text and caret, so the range cannot drift between
show and commit.

### The commit must not re-arm

Committing writes the chosen word into the prefix the trigger matched and leaves
the trigger itself in the text, so the commit's own value write would re-arm it
and put the popup straight back up. `insertSelectedWord()` therefore sets a
one-shot flag that `generateSuggestions()` consumes on its next call.

The set and the consume land in one call stack: `insertSelectedWord` sets it
immediately before its value write, and `set value` calls `generateSuggestions`
synchronously up to its first `await` — which is past both the flag's read and
its clear. So no second clearing site exists, and none is needed: the only early
returns in `set value` that skip the `generateSuggestions` call both require an
active IME composition or a read-only field, and either of those keeps the popup
from showing in the first place, so no accept can be in flight.

## Out of scope

- Snippet/template expansion, and any change to what `Autocompleter` matches.
- Keeping the popup open across a commit to re-filter incrementally.
- Removing the trigger text from the document on accept.

## Acceptance criteria traceability

| # | criterion | where |
|---|---|---|
| 1 | public API registers one or more triggers + callback | `CustomAutocompleteTrigger`, `CodeController.customAutocompleteTriggers` |
| 2 | keyword completer unchanged with no trigger registered | no-trigger tests, plus the full existing suite |
| 3 | callback narrows as more of the trigger follows | narrowing tests over `f` / `fo` / `foo` |
| 4 | tests cover a trigger, narrowing, and the default path | all three groups |
