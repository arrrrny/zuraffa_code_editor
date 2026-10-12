# Verification: scala-unclosed-import-fold

Verdict: **PASS** — 8/8 semantic mutants killed, 1 equivalent, 100% line
coverage.

## Scope

An unclosed Scala selective-import brace (`import users.{` whose `}` never
arrives) must behave exactly as it did before #135: the block below the import
folds, and the unmatched brace is reported at the **opening** line. Regression
introduced by `c70a5ae` (the remediation merged with #135).

## Evidence

| Gate | Result |
| --- | --- |
| `flutter test test/src/folding/` | 97 green (96 baseline + 1 new) |
| `flutter test` (full suite) | 831 green |
| `dart format --set-exit-if-changed` | clean (291 files, 0 changed) |
| `flutter analyze --fatal-infos` | No issues found |
| `flutter test --coverage` + `tool/coverage_gate.py --min 100` | **100.00% (3469/3469)** — OK |

## RED → GREEN

- Red: new Scala test "An unclosed import brace keeps the block below it
  folding." expected `[braces(3..7), braces(4..6)]` + `invalid:[startLine:0]`,
  got `[braces(4..6)]` (and an endLine-only invalid the block matcher never
  reached).
- Red: the `c70a5ae` test "An unclosed import brace stops absorbing after a
  keyword line." re-pinned to `[braces(1..5), braces(2..4)]` +
  `invalid:[startLine:0]`, got `[braces(2..4)]` + `invalid:[endLine:5]`.
- Green: `highlight.dart` keeps `c70a5ae`'s `_foundImportQualifier` gate and
  replaces the depth counter with a stack of open absorbed pairs;
  `onImportTerminatorLine` re-registers every still-open absorbed pair via
  `startBlock(line, type)` before clearing, so `finalize` reports it invalid at
  its opening line and the pairs that follow pair normally.

## Mutation testing

9 mutants against the full folding suite (the Go and JS guards live in other
files, so the whole suite is the scope):

| Mutant | Target | Verdict |
| --- | --- | --- |
| M-noabandon | `onImportTerminatorLine` returns unconditionally | KILLED — both new Scala tests |
| M-norestart | clear the stack without re-registering | KILLED — both new Scala tests |
| M-restart-last-only | re-register only the innermost pair | KILLED — the class block folds but `invalid` loses `startLine:0` |
| M-restart-wrong-type | re-register with the wrong block type | KILLED — invalid block type differs |
| M-noexitpop | closing arm does not pop the stack | KILLED — the closed Scala import stops folding as `imports` |
| M-noabsorbbrace | the qualifier gate never absorbs | KILLED — the closed Scala import loses its fold |
| M-noqualifiergate | absorb any brace on an import line (the `c70a5ae` regression) | KILLED — the JS/TS suite |
| M-wrongline | re-register at the wrong line | KILLED (compile-red: `_lineIndex` is library-private to `text.dart`; excluded from the semantic count) |
| M-clear-before-restart | copy, clear, then re-register | **EQUIVALENT** — a refactor, not a behaviour change |

## Coverage

`tool/coverage_gate.py` at 100% with no new exemption. The `highlight.dart`
`possibleImport` exemption moved **120 → 123** (three lines added above it by
the stack's doc comment and helpers) and its reason is unchanged: no highlight
mode produces `KeywordSemantics.possibleImport`.

## Follow-ups

- The same abandonment shape exists for a terminator that is not a keyword
  line (e.g. a multi-line string): `_processString` ends the sequence without
  consulting the stack. Covered behaviour is unchanged today because no
  absorbed import can contain a template literal in JS (no qualifier gate), but
  the Scala `"""` case is worth its own probe later.
