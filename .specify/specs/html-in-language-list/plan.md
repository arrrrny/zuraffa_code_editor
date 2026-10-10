# Plan — HTML in the language list (#40)

## Premise (verified)

`highlight` 0.7.0's registry holds `xml`, whose `aliases` are
`[html, xhtml, rss, atom, xjb, xsd, xsl, plist, wsf, svg]`. There is no `html`
mode — `~/.pub-cache/.../highlight-0.7.0/lib/languages/` has no `html.dart`, and
`Mode` (highlight's `src/mode.dart`) has no `name` field, so the mode object
itself cannot even be asked for a name. An alias in `highlight` is metadata;
`Highlight.registerLanguage(name, mode)` is the only way a name becomes
resolvable, and nothing registers `html`.

A probe run against real HTML
(`<!DOCTYPE html>`, an element with a quoted and a bare attribute, a comment,
text, a nested element) through both `highlight.parse(..., language: 'xml')` and
a `CodeController` built with `language: xml` produced identical trees:

```
<span class="hljs-meta">&lt;!DOCTYPE <span class="hljs-meta-keyword">html</span>&gt;</span>
<span class="hljs-tag">&lt;<span class="hljs-name">div</span> <span class="hljs-attr">class</span>=<span class="hljs-string">"a"</span> <span class="hljs-attr">id</span>=<span class="hljs-string">b</span>&gt;</span><span class="hljs-comment">&lt;!-- c --&gt;</span>hi<span class="hljs-tag">&lt;/<span class="hljs-name">div</span>&gt;</span>
```

So HTML is already highlighted correctly. The defect is that a consumer has no
way to *find* that out: `README.md` links the mode-variable list without
mentioning that HTML is one of `xml`'s aliases, and the one language list in the
repo — the example's picker — has no HTML entry.

## Changes

### 1. `README.md` — `Languages › Syntax Highlighting`

After the "use a corresponding variable" paragraph, add a short block: `highlight`
defines no `html` mode; HTML and its sibling markup formats (`xhtml`, `rss`,
`atom`, `xjb`, `xsd`, `xsl`, `plist`, `wsf`, `svg`) are highlighted by `xml`:

```dart
import 'package:highlight/languages/xml.dart'; // highlights HTML too

CodeController(text: html, language: xml, ...);
```

This is the actual fix for the issue: it is what a consumer reads.

### 2. `example/lib/03.change_language_theme/constants.dart`

Add `html` and `xml` to both `builtinLanguages` and `languageList`, both mapping
to `highlight`'s `xml` mode, with a comment recording that no dedicated `html`
mode exists and that the two entries deliberately share one `Mode` instance.

Home screen wiring already handles this: `DropdownSelector(values: languageList)`
feeds `_setLanguage`, which does `_codeController.language = builtinLanguages[value]`.
`CodeController.setLanguage` early-returns when the new mode is identical to the
current one, so moving between the two entries is a no-op rather than a re-parse.

### 3. `test/src/highlight/html_language_test.dart`

Four tests per the test list. Uses the existing `pumpController` helper from
`test/src/common/create_app.dart`, which disposes the controller through
`TestApp` — no extra `addTearDown`.

The `xml` mode is a single top-level `final` in `highlight`, shared by every
test in the suite. `CodeController.setLanguage` registers the mode under
`language.hashCode.toString()`, and that id is derived from the mode's identity,
so two tests sharing the `xml` mode land on the same registry key. No
order-dependence is introduced.

## Out of scope

Forking `highlight` to add an `html` mode; highlighting `<script>`/`<style>`
bodies as JS/CSS (the mode declares `subLanguage` entries for both, but its
`<script`/`<style` tag modes never match them in 0.7.0); a public
language registry or name-based selection on `CodeController`; changing the other
7 example entries.

## Verification

```bash
flutter test test/src/highlight/html_language_test.dart   # new
flutter test                                              # full suite
rm -rf coverage && flutter test --coverage \
  && python3 tool/coverage_gate.py --min 100
git checkout -- example/                                  # before coverage
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
```
