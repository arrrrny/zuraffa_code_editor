# TDD cycle log — #62 sub-language embedding never highlights

## Cycle 0 — reproduce

Read `highlight-0.7.0/lib/src/highlight.dart:352-355` and confirmed the
mechanism: a single-element `subLanguage` reference is looked up **by name**,
and a missing name makes `_processSubLanguage` return one plain node.

Two probes, both deleted before committing:

- `CodeController(text: '# Title\n\nSome <b>html</b> here.\n', language: markdown)`
  → `<span class="hljs-section"># Title</span>` … `Some &lt;b&gt;html&lt;/b&gt; here.`
- `CodeController(text: '/// Doc with *emphasis* and `code`\nvoid main() {}\n', language: dart)`
  → `<span class="hljs-comment">/// Doc with *emphasis* and `code`</span>`

Both confirmed, and the second one settled the fix shape: the reference is not
on the top mode, so `language.subLanguage` alone cannot be the whole answer.

## Cycle 1 — red

`test/src/code_field/sub_language_embedding_test.dart`, seven tests. Three
compile errors on the way:

- `Mode` has no `const` constructor, so the hand-built embedder in test 4 has
  to be `final`;
- the HTML expectation in test 4 has to be the escaped `&lt;b&gt;`, because
  `Result.toHtml()` escapes text nodes;
- a `..dispose()` cascade on a constructor expression trips
  `avoid_single_cascade_in_expression_statements`.

Red, and each of tests 1–3 fails on its own unique sub-language name, which is
what makes them order-independent.

## Cycle 2 — green

First attempt registered only `language.subLanguage` — the top mode. Markdown's
`subLanguage` is `null` (the reference is inside `contains`), so nothing
changed. Replaced with the tree walk over `contains` / `variants` / `starts` /
`refs`, guarded by an identity `Set<Mode>` so a self-referencing mode cannot
loop. Both repros then highlighted.

Coverage came back at 99.97 % with one uncovered line,
`code_controller.dart:323` — the `starts` branch, because no test used a
language with a terminal-mode sub-language. Rather than exempt it, added the
dockerfile `RUN` test, whose bash embedder *is* a `starts`. That took coverage
to 100.00 % (3165/3165) and is a real-world case in its own right.

## Cycle 3 — fault injection

Commented out only the `_registerSubLanguages(language)` call:

```
+0 -1: markdown highlights the HTML it embeds [E]
+0 -2: dart highlights a doc comment as markdown [E]
+0 -3: dockerfile highlights a RUN body as bash [E]
+1 -4: registering the embedded languages is reversible per language [E]
+3 -4: Some tests failed.
```

Four detect the defect; three are guards.

## Scratch removed

`test/src/code_field/zz_probe_sub_lang_test.dart`,
`test/src/code_field/zz_probe2_test.dart`,
`test/src/code_field/zz_probe_docker_test.dart`. `test/coverage_helper_test.dart`
and `coverage/` were never committed.
