# Verification: scala-multiline-imports-117

Verdict: **PASS** — 3/3 mutants killed, no survivors, 100% line coverage.

## Scope

Multi-line Scala selective imports (`import users.{ User,\n  UserPreferences }`)
fold as ONE imports block instead of a stray braces block that terminates the
import sequence. Absorption is brace-only at the top level; inner pairs are
absorbed by depth. Go's `import ( ... )` group keeps its own fold.

## Evidence

| Gate | Result |
| --- | --- |
| `flutter test test/src/folding/` | 88 green |
| `flutter test` (full suite) | 822 green (819 post-#81 master + 3 net: one TODO test replaced by four) |
| `dart format --set-exit-if-changed` | clean (12 files, 0 changed) |
| `flutter analyze --fatal-infos` | No issues found |
| `flutter test --coverage` + `tool/coverage_gate.py --min 100` | **100.00% (3446/3446)** — OK |

## Mutation testing

Run against the full folding suite (the Go guard lives in
`highlight_parser_go_test.dart`, a different file — scoping a mutant to the
Scala test file alone produced a false SURVIVED for M-abs in the first audit).

| Mutant | Target | Verdict |
| --- | --- | --- |
| M-noabs | `_startPairOrBlock` never absorbs (`const absorb = false`) | KILLED |
| M-close | `_endPairOrBlock` closing arm drops `setFoundPossibleImport()` | KILLED |
| M-abs | `_startPairOrBlock` absorbs any pair type (brace-only guard removed) | KILLED |
| M1 | `text.dart:submitCurrentLine` depth arm replaced with `if (false && …)` | **PRUNED** |

M1's verdict is the one audit finding, resolved by deletion instead of
exemption:

- The arm submitted `possibleImport` for every inner line of an absorbed
  block. Inner lines are no-ops for `endImportSequenceIfAny`
  (`singleLineCommentTerminator`/`possibleImport`/blank all `break`), so their
  semantics never reach the block; only the closing line's `possibleImport`
  sets `last`, and that is produced by `highlight.dart`'s closing arm. The
  arm was therefore unobservable dead weight.
- The depth state was moved from `text.dart` into `highlight.dart` (its only
  consumer), and the arm was deleted. M1's mutation target no longer exists.
  `text.dart` now differs from master only by a doc-typo fix; no coverage
  exemption is needed for it.

## Coverage

`tool/coverage_gate.py` at 100% with 9 exempted lines (whole files plus the
`highlight.dart:111` `possibleImport` case that no highlight mode can produce,
and `text.dart:49`). The absorption made the four previously-exempted
`text.dart` lines genuinely covered — `setFoundPossibleImport` and the
`possibleImport` branch are now reached by the closing line of an absorbed
block — so those exemptions were removed in the feature commit rather than
renumbered. The insertion for the prune shifted `highlight.dart`'s exemption
93 → 111.

## Perf pin

`no_language_keystroke_test.dart` failed once during a `--coverage` run.
Control on clean master: 813/813 green. Standalone on this branch: 64 ms
vs the 100 ms bound. The fixture contains no imports, so the absorption path
never executes; the failure was machine load under coverage instrumentation,
not a regression. No code change; flagged here so the pool's CI noise is not
mistaken for a real red.
