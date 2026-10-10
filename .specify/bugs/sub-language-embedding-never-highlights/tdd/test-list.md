# TDD test list — #62 sub-language embedding never highlights

Status: **root cause measured; source change landed.**

| # | Test | Kind | State |
|---|------|------|-------|
| 1 | `markdown highlights the HTML it embeds` | **fault-detecting** | green |
| 2 | `dart highlights a doc comment as markdown` | **fault-detecting** | green |
| 3 | `dockerfile highlights a RUN body as bash` | **fault-detecting** | green |
| 4 | `an embedded language outside the bundled set stays plain` | documents the boundary | green |
| 5 | `registering the embedded languages is reversible per language` | **fault-detecting** | green |
| 6 | `languageId keeps reporting the language hashCode` | pins unchanged public API | green |
| 7 | `the embedded languages really are in the highlight registry` | pins the registry effect | green |

`test/src/code_field/sub_language_embedding_test.dart`

Each of tests 1–3 uses a different sub-language name (`xml`, `markdown`,
`bash`), so none of them can pass on a registration another test made. That
matters: the registry behind `package:highlight/highlight_core.dart` is
process-global and can only grow, so a test that shared a name would pass or
fail on which test ran first rather than on the code.

## Red → green

Red at `c261235` (before the registration), with the
`_registerSubLanguages(language)` call removed from `setLanguage`:

```
Expected: contains 'hljs-tag'
  Actual: 'Some &lt;b&gt;html&lt;/b&gt; here.'
   Which: does not contain 'hljs-tag'

Expected: contains '<span class="markdown">'
  Actual: '<span class="hljs-comment">/// Doc with *emphasis* and `code`</span>\n'
```

Tests 1, 2, 3 and 5 fail. Tests 4, 6 and 7 pass either way — 4 and 6 are
guards, and 7 reads the *other* `highlight` instance
(`package:highlight/highlight.dart`), which is pre-registered with every mode,
so it is a smoke test of the API rather than of this fix.
