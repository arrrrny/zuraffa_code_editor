# Feature: Support HTML in the language list

**Issue:** [arrrrny/zuraffa_code_editor#40](https://github.com/arrrrny/zuraffa_code_editor/issues/40) — synced from upstream `akvelon/flutter-code-editor#277 — "Support HTML language"`.
**Label:** `spec`

## Problem

The issue asks for HTML in the language list. `highlight` (the parser this
package relies on) ships **no `html` mode at all**: its registry holds `xml`,
whose `aliases` claim `"html", "xhtml", "rss", "atom", "xjb", "xsd", "xsl",
"plist", "wsf", "svg"`. An alias is not a registration, so nothing in the
ecosystem can hand a consumer a mode *named* `html`.

Consequences today:

- The example's language picker (`example/lib/03.change_language_theme/constants.dart`)
  offers 7 languages, none of them HTML, so the demo cannot show it.
- `README.md`'s "Syntax Highlighting" section says "use a corresponding
  variable" and links the ~190 mode files, which reads as "whatever variable
  name you want must exist". A consumer who goes looking for
  `package:highlight/languages/html.dart` finds nothing and concludes HTML is
  unsupported — exactly the conclusion in the issue.

Meanwhile upstream's own answer on #277 is "it supports HTML, use xml", and the
probe in this spec confirms it: the `xml` mode renders real HTML correctly
(doctype → `meta`/`meta-keyword`, open and close tags → `tag` with the element
name in `name`, attributes → `attr`, quoted and bare values → `string`,
comments → `comment`), and `CodeController` produces the identical tree.

So the capability exists and works; the gap is discoverability, not parsing.

## Scope

Make HTML selectable and document how it is reached:

1. `README.md`, "Languages › Syntax Highlighting": state that HTML and its
   sibling markup formats are highlighted by the `xml` mode, and that
   `highlight` exposes no `html` mode of its own.
2. `example/lib/03.change_language_theme/constants.dart`: add `html` (and
   `xml`, so the answer "use xml" is reachable too) to `builtinLanguages` and
   `languageList`, both mapping to `highlight`'s `xml` mode.
3. A test pinning the claim in (1) against the code: a `CodeController` built
   with the `xml` mode highlights real HTML with the expected node classes.

No new highlighter, no forked `highlight`, no new public API on the package.

## Non-goals

- A dedicated `html` mode in `highlight`: that is an upstream gap in
  `highlight`, not something this package should fork or shadow.
- A public language registry or name-based language selection on
  `CodeController`: `setLanguage` takes a `Mode`, and the issue asks for a list
  entry, not for a new selection API.
- Highlighting `<script>`/`<style>` bodies as JavaScript/CSS: `xml`'s mode does
  declare `subLanguage` entries for both, but its `<script`/`<style` tag modes
  never match them in `highlight` 0.7.0, so the bodies stay markup.
- Changing the example's language set beyond HTML/`xml`.

## Acceptance criteria

1. The example's language dropdown includes `html`, and selecting it highlights
   an HTML document (tag, attr, string, comment and meta spans present).
2. `README.md` tells a consumer that HTML is reached through the `xml` mode and
   that `highlight` has no `html` mode.
3. A test proves the README's claim: real HTML parsed through `CodeController`
   with the `xml` mode yields the expected node classes.
4. The existing 7 entries keep working and no other behavior changes.
