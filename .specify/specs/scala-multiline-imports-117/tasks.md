# Tasks: scala multiline imports

**Spec:** ./spec.md · **Plan:** ./plan.md · **Test list:** ./test-list.md

## Phase 1 — the tests (red)

- [ ] T1 `test/src/folding/parsers/highlight_parser_scala_test.dart`: replace
      the TODO-pinned "Multiline imports form braces foldable block" with
      "Multiline imports form one imports foldable block" expecting
      `FB(firstLine: 0, lastLine: 3, type: FBT.imports)` only, and add the
      nested-pair, no-trailing-newline and absorbed-multiline-comment cases.
      Red on the old base: the braces block is still reported and the imports
      block stops at the import line.

## Phase 2 — the semantics arm (behaviour)

- [ ] T2 `lib/src/folding/parsers/text.dart`: `_importPairBlockDepth`,
      `enterImportPairBlock`, `exitImportPairBlock` (protected, parser state —
      not cleared by `clearLineFlags`).
- [ ] T3 `lib/src/folding/parsers/text.dart`: the `submitCurrentLine` arm
      submitting `possibleImport` while depth > 0, after the terminator arm.

## Phase 3 — the absorption (behaviour)

- [ ] T4 `lib/src/folding/parsers/highlight.dart`: absorb the open pair
      character when `foundImport || depth > 0` (no `startBlock`), exit and
      `setFoundPossibleImport()` on the matching close when depth > 0.

## Phase 4 — records

- [ ] T5 `tool/coverage_gate.py`: renumber the `text.dart` exemptions (27, 28)
      for the lines inserted above them.
- [ ] T6 `CHANGELOG.md`: entry naming fork issue #117 and upstream
      `akvelon/flutter-code-editor#78`.
- [ ] T7 Coverage gate: `flutter test --coverage` +
      `python3 tool/coverage_gate.py --min 100`, cleaning the helper test and
      `coverage/` afterwards.

## Dependencies

T2/T3 and T4 together take T1 green (the depth flag is shared state between
the two files; T4 alone would emit `possibleImport` for the closing line but
inner lines would still terminate). T5 must count the T2/T3 insertions.
T6–T7 are records.

## Test inventory (for T1)

1. **One imports block** — `import users.User` + multi-line
   `import users.{ User }` → `FB(0,3,imports)` only; no braces FB.
2. **Member list with its own pairs** — `(a, b)` inside the braces produces
   no extra block (nested absorption).
3. **No trailing newline** — the import list ends the file; `finalize` still
   emits one imports block.
4. **Absorbed multiline comment** — `/* … */` inside the member list does not
   break the sequence, and its own multilineComment FB still forms.
5. **Single-line selective import unchanged** —
   `import users.{User, UserPreferences}` on one line behaves as today
   (covered by the existing "Imports at the beginning" test, kept green).

## Parallelism

T2/T3 same file (sequential); T4 depends on T2; T5 after T2/T3; T6/T7 last.
