# Test list — HTML in the language list (#40)

File: `test/src/highlight/html_language_test.dart`.
Fixtures: a small but representative HTML document — doctype, an element with
quoted and bare attributes, a comment, text, a nested element, an unclosed
attribute value and an entity reference.

1. HTML highlights through a `CodeController` whose language is `highlight`'s
   `xml` mode: open and close tags carry `tag` with the element name in `name`,
   attributes carry `attr`, quoted and bare attribute values carry `string`,
   and the comment carries `comment`.
   → RED if the node walk or the controller's highlight step regresses; this is
   the pin behind the README's "use xml for HTML" claim.
2. The doctype is highlighted as `meta`, with `meta-keyword` on the `html` word.
   → RED if the prologue handling is lost — a pin on (1) alone would still pass
   on a mode that ignores the doctype entirely.
3. Every character survives the round-trip: the node values concatenated in
   document order reconstruct the input exactly.
   → RED if the mode swallows or duplicates text — the first thing the issue's
   reader would notice as "HTML doesn't work".
4. `xml.aliases` contains `html`.
   → RED if a future `highlight` release drops the alias or adds a dedicated
   `html` mode, at which point the example entry must point at the new mode.

Not a unit test: the example's `builtinLanguages`/`languageList` entries are in
`example/`, which the package's tests cannot import (the dependency runs the
other way). They are guarded by the `dart analyze --fatal-infos` and
`dart format --set-exit-if-changed` steps, which both cover `example/`, and
were verified by running the demo's language switch.
