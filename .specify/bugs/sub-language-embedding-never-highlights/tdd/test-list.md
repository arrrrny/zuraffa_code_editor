# TDD test list — #62 sub-language embedding never highlights

Status: **root cause measured; source change landed; review findings folded in.**

| # | Test | Kind | State |
|---|------|------|-------|
| 1 | `markdown highlights the HTML it embeds` | **fault-detecting** | green |
| 2 | `dart highlights a doc comment as markdown` | **fault-detecting** | green |
| 3 | `dockerfile highlights a RUN body as bash` | **fault-detecting** | green |
| 4 | `a second-level embed highlights (php inside xml inside markdown)` | **fault-detecting** (the transitive step) | green |
| 5 | `an embedded language outside the bundled set stays plain` | documents the boundary | green |
| 6 | `registering the embedded languages is reversible per language` | **fault-detecting** | green |
| 7 | `languageId keeps reporting the language hashCode` | pins unchanged public API | green |
| 8 | `the embedded languages really are in the highlight registry` | **fault-detecting** (reads the registry the controller writes) | green |

`test/src/code_field/sub_language_embedding_test.dart`

Each of tests 1–4 drives a sub-language name no other test registers — `xml`,
`markdown`, `bash`, and `php` — so none of them can pass on a registration
another test made. That matters: the registry behind
`package:highlight/highlight_core.dart` is process-global and can only grow, so
a test that shared a name would pass or fail on which test ran first rather
than on the code.

## Red → green

First red at `c261235` (before the registration), with the
`_registerSubLanguages(language)` call removed from `setLanguage`:

```
Expected: contains 'hljs-tag'
  Actual: 'Some &lt;b&gt;html&lt;/b&gt; here.'
   Which: does not contain 'hljs-tag'

Expected: contains '<span class="markdown">'
  Actual: '<span class="hljs-comment">/// Doc with *emphasis* and `code`</span>\n'
```

With the call removed, tests 1, 2, 3, 4, 6 and 8 fail. Test 8 fails because it
now parses through the `highlight_core` instance the controller registers
into; the original version read `highlight.dart`'s pre-seeded global, where
the names resolve with or without the controller. Tests 5 and 7 are guards and
pass either way.

Reducing the walk to the top language's own references (no transitive step)
fails test 4 alone: it is the regression detector for `markdown → xml → php`.

