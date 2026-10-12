# Cycle Log: scala-unclosed-import-fold

Engine: raw (`.specify/memory/tdd-profile.md`). One behavior at a time:
red proven → smallest change → green → tick.

## Baseline — 2026-10-12

- Suite: `flutter test --concurrency=2 test/src/folding/` on
  `fix/scala-unclosed-import-fold` @ `1d09ab8` (post-#135 master).
- Test list written: 6 behaviors (B1–B6 acceptance, C1 characterization).
- Behaviors DONE: 0/6.

## Loop — 2026-10-12

- **Red (B1/B2)**: new Scala test "An unclosed import brace keeps the block
  below it folding." — expected `[braces(3..7), braces(4..6)]` +
  `invalid:[startLine:0]`, actual `[braces(4..6)]` (+ an endLine-only invalid
  the block matcher never reached). RED on the committed tree.
- **Red (B3)**: the `c70a5ae` test "An unclosed import brace stops absorbing
  after a keyword line." re-pinned to the restored behaviour —
  `[braces(1..5), braces(2..4)]` + `invalid:[startLine:0]`; actual
  `[braces(2..4)]` + `invalid:[endLine:5]`. RED.
- **Green (B1–B5)**: `highlight.dart` keeps the qualifier gate from `c70a5ae`
  and replaces the depth counter with a stack of open absorbed pairs
  (`_absorbedOpens`). `onImportTerminatorLine` now re-registers every
  still-open absorbed pair via `startBlock(line, type)` before clearing, so
  `finalize` reports it invalid at its **opening** line and the pairs that
  follow pair normally. The abandoned import behaves exactly as pre-#135 for
  both blocks and the diagnostic.
- **Characterization (C1)**: the whole folding suite is green (97 = 96 + 1).
- **Renumber**: the `highlight.dart` coverage exemption moved 120 → 123 (three
  lines added above it: the stack's doc comment and the `_AbsorbedPair` helpers).

## Mutation audit

9 mutants against the full folding suite:

| Mutant | Target | Verdict |
| --- | --- | --- |
| M-noabandon | `onImportTerminatorLine` returns unconditionally | KILLED — both new Scala tests |
| M-norestart | clear the stack without re-registering | KILLED — both new Scala tests |
| M-restart-last-only | re-register only the innermost pair | KILLED — the outer class block folds but `invalid` loses `startLine:0` |
| M-restart-wrong-type | re-register with the wrong type | KILLED — invalid block type differs |
| M-noexitpop | closing arm does not pop the stack | KILLED — the closed Scala import stops folding as `imports` |
| M-noabsorbbrace | the qualifier gate never absorbs | KILLED — the closed Scala import loses its fold |
| M-noqualifiergate | absorb any brace on an import line (`c70a5ae` regression) | KILLED — the JS/TS suite |
| M-wrongline | re-register at the wrong line | KILLED (compile-red: `_lineIndex` is library-private to `text.dart`; kept out of the semantic count) |
| M-clear-before-restart | copy, clear, then re-register | **EQUIVALENT** — a refactor, not a behaviour change |
