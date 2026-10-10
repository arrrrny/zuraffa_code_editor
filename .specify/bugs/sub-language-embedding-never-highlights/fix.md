# #62 — Sub-language embedding never highlights

- **Status:** fixed
- **Label:** `bug`
- **Source:** this repo, found while reproducing #33

## Reported symptom

No embedded fragment ever highlights, in any language. Markdown's
`<b>html</b>` is one plain node, dart's doc comments are one flat
`hljs-comment` node, dockerfile's `RUN` bodies are never tokenised as bash.

## Where the bug actually lives

`highlight` resolves an embedded sub-language **by name**:
`_processSubLanguage` (highlight-0.7.0 `lib/src/highlight.dart:352-355`) does

```dart
var explicit = top!.subLanguage!.length == 1;
if (explicit && _languages[top!.subLanguage!.first] == null) {
  return [Node(value: mode_buffer)];   // give up: one plain node
}
```

`CodeController.setLanguage` registers the language it is handed under
`language.hashCode.toString()`. A `Mode` carries no name field (only
`aliases`/`ref`), so that synthetic key is the only identity the controller
has for the top-level language — and it means none of the names a mode
references (`xml`, `markdown`, `bash`, `ruby`, …) exist in the registry.
Nothing throws; the fragment just never highlights.

Two further facts shape the fix:

- the references live on **child** modes, not the top one — markdown's
  `Mode(begin: "<", end: ">", subLanguage: ["xml"])` is an entry in its
  `contains`, and dockerfile's bash embedder is a `starts`;
- `package:highlight/highlight_core.dart` (what the controller imports) starts
  with an **empty** registry, unlike `package:highlight/highlight.dart` which
  pre-registers all ~190 modes.

## The change

- `lib/src/highlight/sub_languages.dart` — new: the name → [`Mode`] map for the
  28 names the bundled modes actually reference. This is the referenced set, not
  the whole ~190-mode registry, so a consumer of this package does not carry
  every language mode. A reference outside it falls back to plaintext exactly as
  before; registering one more is a one-line
  `highlight.registerLanguage(name, mode)`. Its header also records that
  registration is unconditional: a mode a consumer registered under one of
  these names is replaced the next time a language embedding that name is set.
- `lib/src/code_field/code_controller.dart` — `setLanguage` now also calls
  `_registerSubLanguages(language)`, which walks `contains` / `variants` /
  `starts` / `refs` (skipping already-seen modes so a self-referencing mode
  cannot loop), registers every reachable reference by name, and then follows
  the referenced languages' own references through the same map — so a
  second-level embed (`markdown → xml → php`) is registered too. Each name is
  handled once, which bounds the walk over the 28-entry map even though some
  modes reference each other in a cycle (xml and xquery include themselves;
  perl and mojolicious reference one another).

`CodeController.languageId` is untouched: it still returns the language's
`hashCode`, which two existing tests pin as public behaviour. Only the
sub-language names are added to the registry.

## Tests

`test/src/code_field/sub_language_embedding_test.dart` — eight tests:

| # | Test | Asserts |
|---|------|---------|
| 1 | markdown highlights the HTML it embeds | `hljs-tag` and `<span class="xml">` |
| 2 | dart highlights a doc comment as markdown | `<span class="markdown">`, `hljs-emphasis`, `hljs-code`, and the code outside stays dart |
| 3 | dockerfile highlights a RUN body as bash | `<span class="bash">` — drives the `starts` branch |
| 4 | a second-level embed highlights (php inside xml inside markdown) | `<span class="php">` — drives the transitive walk |
| 5 | an embedded language outside the bundled set stays plain | the fragment is still one plain node |
| 6 | registering is reversible per language | switching away and back still highlights |
| 7 | languageId keeps reporting the language hashCode | public API unchanged |
| 8 | the embedded languages really are in the highlight registry | reached through `highlight.parse` on the `highlight_core` instance the controller registers into |

## Fault-detecting power

Reverting only the `_registerSubLanguages(language)` call in `setLanguage`
fails tests 1, 2, 3, 4, 6 and 8:

```
+0 -1: markdown highlights the HTML it embeds [E]
+0 -2: dart highlights a doc comment as markdown [E]
+0 -3: dockerfile highlights a RUN body as bash [E]
+0 -4: a second-level embed highlights (php inside xml inside markdown) [E]
+1 -5: registering the embedded languages is reversible per language [E]
+2 -6: the embedded languages really are in the highlight registry [E]
+2 -6: Some tests failed.
```

Tests 5 and 7 are guards by design — they pass either way and pin the boundary
and the unchanged public API.

Reducing the walk back to one level — the top language's own references only —
fails test 4 alone, so the transitive step has its own regression detector.

## Gate note

No `EXEMPT_LINES` change was needed. Coverage is 100.00 % (3170/3170) and the
full suite is 591 tests. The `starts` walk is covered by the dockerfile test,
and the transitive loop's lines by the existing tests — the handled-skip by
xml's self-reference, the outside-map skip by the outside-set test — rather
than exempted.
