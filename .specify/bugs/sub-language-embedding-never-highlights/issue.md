# Bug Issue: Sub-language embedding never highlights: languages are registered under hashCode, not their real name

- **Slug**: sub-language-embedding-never-highlights
- **Fetched**: 2026-10-10
- **Issue**: 62
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/62
- **State**: open
- **Severity**: high
- **Author**: arrrrny
- **Labels**: bug

## Body

Issued from this repo during the triage of #33 (HTML/XML highlighting renders
incorrectly). While building a reproduction for #33 it turned out that the
embedded fragment was never handed to a sub-language at all, which is a
separate and much wider defect than #33's own theme complaints.

`highlight` resolves an embedded sub-language **by name** out of its language
registry — `_processSubLanguage` (highlight-0.7.0
`lib/src/highlight.dart:352-355`) checks `_languages[top.subLanguage.first]`
and, when the name is missing, returns the fragment as one plain node.
`CodeController.setLanguage` registers the language it is handed under
`language.hashCode.toString()` (`code_controller.dart:252-254`), so no bundled
name is ever in the registry and **every** embedded fragment in **every**
language silently falls back to plaintext.

## Reproductions

- `language: markdown`, text `Some <b>html</b> here.` — `<b>` is one plain node
- `language: dart`, text `/// Doc with *emphasis* and `code`\nvoid main() {}` —
  the doc comment is one flat `hljs-comment` node

Affected by the same root cause: markdown→xml, dart→markdown,
dockerfile→bash, asciidoc→xml, coffeescript→javascript, erb/haml→ruby,
handlebars/htmlbars/dust→xml, and every other `subLanguage` in the bundled
modes.

## Acceptance criteria

- [x] Root cause identified: whose registry key is wrong and why it is silent
- [ ] An embedded fragment highlights through its sub-language
- [ ] A language that embeds nothing is unaffected
- [ ] A reference outside the bundled set stays plaintext (honest boundary)
- [ ] `CodeController.languageId` keeps its documented value
