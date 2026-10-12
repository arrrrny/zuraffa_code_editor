# Cycle Log: scala-multiline-imports-117

Engine: raw (`.specify/memory/tdd-profile.md`). One behavior at a time:
red proven → smallest change → green → tick.

## Baseline — 2026-10-12

- Suite: `flutter test` on `spec/scala-multiline-imports-117` @ `21d528f`
  (master `0a31d8e` + spec/plan/tasks commits).
- Test list written: 8 behaviors (A1–A4 acceptance, C1 characterization).
- Behaviors DONE: 0/8.

## Loop — 2026-10-12

- **Red (T1)**: replaced the TODO-pinned "Multiline imports form braces
  foldable block" with four tests — one imports block, nested pairs in the
  member list, a lone multi-line import, absorbed multiline comment. 4 red,
  15 pre-existing Scala tests green.
- **Green (T2–T4)**: `text.dart` gained `_importPairBlockDepth` +
  `enter/exitImportPairBlock` + `inImportPairBlock` and a `submitCurrentLine`
  arm submitting `possibleImport` while inside; `highlight.dart` gained
  `_startPairOrBlock`/`_endPairOrBlock` — absorb a brace opened on an import
  line, exit + `setFoundPossibleImport()` on the matching close.
- **Design correction found by the red suite**: the first version absorbed
  ALL pair characters opened on an import line. The Go parser tests caught it
  — Go's `import ( ... )` group is pinned as its own `parentheses` FB
  (`highlight_parser_go_test.dart` → "Multiline imports"). Absorption is now
  brace-only at the top level; inner pairs are absorbed by depth. Spec's
  decision bullet updated to record this.
- **Expectation fix (mine, not the code's)**: the absorbed-multiline-comment
  test first expected `multilineComment(1,4)`; the `*/` closes on line 3, so
  `(1,3)` is correct — the code was right.
- `flutter test test/src/folding/` — 88 green. Full suite 816 green (813 + 3
  net new: one TODO test replaced by four). `dart analyze --fatal-infos`
  clean, `dart format` clean.
- **Coverage exposure**: the absorption made four `text.dart` exemptions dead
  weight the honest way — `setFoundPossibleImport` and the `possibleImport`
  branch of `submitCurrentLine` are now reached by the closing line of an
  absorbed block, so those exemptions were removed from
  `tool/coverage_gate.py` rather than renumbered. The `highlight.dart:93`
  exemption (no mode produces `possibleImport` keyword semantics) still holds.
- Behaviors DONE: 8/8 (A1–A4, C1). Tasks T1–T4 ticked.

## Audit — 2026-10-12

- **Rebase**: branch rebased onto `25e4c1a` (PR #134 merge). CHANGELOG
  conflict resolved by keeping both the #81 and #117 entries (#117 first).
- **Mutation audit (full folding suite, 88 tests — scope matters: the Go
  guard lives in a different test file)**:
  - M-abs "absorb any pair type": **KILLED** (Go tests red — an earlier run
    scoped to the Scala file only reported a false SURVIVED).
  - M-close "closing line submits no possibleImport": **KILLED** (Scala tests
    red).
  - M1 "the `submitCurrentLine` depth arm never fires": **SURVIVED** — and for
    a real reason. Inner lines of an absorbed block are no-ops for
    `endImportSequenceIfAny` (`singleLineCommentTerminator`/`possibleImport`
    both `break`), so their per-line semantics never reach the block. Only
    the closing line's `possibleImport` sets `last`, and that comes from
    `highlight.dart`'s closing arm, not the arm in `text.dart`. The arm was
    dead weight.
- **Prune**: rather than exempt the dead arm, `_importPairBlockDepth` +
  `enter/exitImportPairBlock` + `inImportPairBlock` moved from `text.dart`
  into `highlight.dart` (its only consumer) and the `submitCurrentLine` arm
  was deleted. M1's target no longer exists, so it cannot survive.
  `text.dart` now differs from master only by a doc-typo fix ("current we" →
  "current line"), and the four `text.dart` exemptions stay removed.
- **Re-audit on the pruned code**: M-noabs "absorption never fires"
  **KILLED**, M-close **KILLED**, M-abs **KILLED** — 3/3, no survivors.
- **Exemption renumber**: the `highlight.dart` `possibleImport` exemption
  moved 93 → 111 after the 18-line insertion. `text.dart:49` unchanged.
- **Perf pin**: `no_language_keystroke_test.dart` failed once during a
  `--coverage` run. Control on clean master 813/813 green; standalone on the
  branch 64 ms vs the 100 ms bound. The fixture has no imports so the
  absorption path never fires — machine load under instrumentation, not a
  regression. No code change.
- **Final**: folding 88 green; full suite 822 green (819 + 3 net);
  `flutter test --coverage` + `tool/coverage_gate.py --min 100` →
  **100.00% (3446/3446)** — OK.

