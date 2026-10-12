# Test List: scala-multiline-imports-117

Derived: 2026-10-12 · Engine: raw (see `.specify/memory/tdd-profile.md`)
Spec: ./spec.md · Plan: ./plan.md

## Acceptance behaviors

- [x] A1 — A multi-line selective import folds as one `imports` block whose
      last line is the closing brace line; no braces FB is reported.
      (AC: "folds as one imports block")
      Traces to: `highlight_parser_scala_test.dart`
- [x] A2 — A member list containing its own pair characters produces no extra
      block. (AC: "member list with its own pairs")
- [x] A3 — An import statement ending at the last line of the file (no
      trailing newline) still produces one imports block. (AC: "ending at the
      last line")
- [x] A4 — A multiline comment inside an absorbed member list still forms its
      own multilineComment block and does not break the imports sequence.
      (AC: "absorbed comment")

## Characterization (regression) behaviors

- [x] C1 — Every pre-existing Scala pair-character test passes unchanged:
      single-line imports stay `imports`, non-import pair blocks untouched.
      (AC: "pair blocks on non-import lines unaffected")

## Coverage obligations

- `lib/src/folding/parsers/text.dart`: new `_importPairBlockDepth > 0` arm —
  true branch by A1–A4, false branch by the rest of the suite. New mutators
  by A1 (enter) and A1 (exit).
- `lib/src/folding/parsers/highlight.dart`: absorb-at-open `foundImport`
  true + `depth > 0` false (A1), absorb-at-open with depth > 0 (A2), exit arm
  (A1), regular open/close arms (C1 + the whole non-Scala suite).
- Gate: 100% line coverage (`tool/coverage_gate.py --min 100`); renumber the
  `text.dart` exemptions (27, 28) and check `highlight.dart`'s (93) after the
  edits.

## Cycle log

See `tdd/cycle-log.md`.
