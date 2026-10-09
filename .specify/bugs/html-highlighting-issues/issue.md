# Bug Issue: HTML/XML highlighting renders incorrectly

- **Slug**: html-highlighting-issues
- **Fetched**: 2026-10-09
- **Issue**: 33
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/33
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
CodeTheme(
          data: CodeThemeData(styles: vsTheme),
          child: CodeField(
            enabled: false,
            controller: CodeController(text: code, language: xml),
          ),
        )
```

`flutter_code_editor: ^0.3.4`

(screenshot on the upstream issue showing mis-highlighted XML)

Synced from upstream `akvelon/flutter-code-editor#311 — "There are issues with the HTML code highlighting"`.

## Why it matters

XML/HTML is one of the languages users reach for first, and the highlighting
output shown in the report is visibly wrong (wrong spans applied).

## Acceptance criteria

- [ ] The reported snippet renders with correct highlighting under `language: xml`
- [ ] Root cause identified (highlight mode definitions, or the fork's span mapping)
- [ ] Regression test pins the token classification

## Comments

None. Related upstream: #277 "Support HTML language" (feature counterpart).
