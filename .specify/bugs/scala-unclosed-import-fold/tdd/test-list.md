# Test List: scala-unclosed-import-fold

Derived: 2026-10-12 · Engine: raw (see `.specify/memory/tdd-profile.md`)
Spec: ./spec.md (no plan.md — bug slice, `outer-only`)

## Acceptance behaviors

- [ ] B1 — An unclosed Scala selective-import brace no longer swallows the
      block below it: `import users.{` … `class MyClass { … }` yields
      `braces(3..7)` **and** `braces(4..6)`, exactly merge-base `25e4c1a`.
      (AC1)
      Traces to: `test/src/folding/parsers/highlight_parser_scala_test.dart`
- [ ] B2 — The same sample reports the unmatched brace at its **opening**
      line: `invalid: [InvalidFoldableBlock(startLine: 0, type: braces)]`,
      not `endLine: 7`. (AC2)
- [ ] B3 — The `c70a5ae` fixture moves with the fix: "An unclosed import brace
      stops absorbing after a keyword line" is re-pinned to the restored
      behaviour for its own sample (class block folds, diagnostic at the
      import line). (AC3)
- [ ] B4 — JS keeps its already-correct behaviour: an unclosed JS import still
      yields `braces(3..5)` + `invalid:[startLine:0]` — the cross-language
      regression guard. (AC4)
      Traces to: `test/src/folding/parsers/highlight_parser_js_test.dart`
- [ ] B5 — The #117 feature is untouched: a closed Scala selective import
      folds as one `imports` block; a member list holding its own pairs
      produces no extra block; Go's parenthesized import group keeps its own
      fold. (AC5)
- [ ] B6 — Coverage stays at the 100% gate with no new exemption. (AC6)

## Characterization (regression) behaviors

- [ ] C1 — Every pre-existing folding test passes unchanged, in every
      language: java, python, go, markup, indent, fallback, plus the #117
      suite's own Scala/Go/JS cases.

## Coverage obligations

- `lib/src/folding/parsers/highlight.dart`: the abandonment path — every line
  of the re-registration loop, the "still-open pairs" and "nothing open"
  branches, and the abandoned pair's later pairing as an ordinary block
  (B1/B2/B4), plus the already-covered happy paths (B5/C1).
- Gate: 100% line coverage (`tool/coverage_gate.py --min 100`); count the
  insertions before running it — `EXEMPT_LINES` pins `highlight.dart:120` by
  number.

## Cycle log

See `tdd/cycle-log.md`.
