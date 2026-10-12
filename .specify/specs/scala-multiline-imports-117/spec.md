# Spec: scala-multiline-imports

Fork issue: #117 · Upstream: akvelon/flutter-code-editor#78
Label: `spec` · Severity: `low` · Backlog rank: 20

## What was asked

"`import users.{ User, UserPreferences }` should fold as one block."
(Where it lives: `lib/src/folding/parsers/`.)

## What exists today

Scala's selective import syntax can span several lines:

```scala
import users.{
  User,
  UserPreferences
}
```

The user expects that whole statement to fold as one imports block, exactly
as a run of single-line `import` lines folds. It does not. The pair-character
machinery opens a braces block on the `{`, the closing `}` ends it, and the
import-sequence grouping stops at the line holding `import` itself — the
browser therefore shows two foldable blocks: `imports` for the import line and
a stray `braces` block for the member list. The wrongness is pinned by a test
(`highlight_parser_scala_test.dart` → "Multiline imports form braces foldable
block") that carries a `TODO(Malarg): handle scala multiline blocks` marker.

The gap is visible in the folded UI in two ways: the braces toggle and the
imports toggle overlap on the same statement, and collapsing "imports" leaves
the selected members on screen — the opposite of what folding an import group
is for.

## What this spec adds

A pair-character block that opens on a line with import semantics belongs to
the import, not to the code:

1. **The import block absorbs it.** The braces (or parentheses/brackets)
   opened on an import line are not reported as their own foldable block;
   the statement folds once, as part of the imports sequence.
2. **The sequence extends through it.** Every line the absorbed block spans —
   members and the closing line — counts as an import line for the import
   sequence, so the `imports` block's last line is the closing `}`.
3. **Everything else is unchanged.** A pair block on a non-import line is a
   block today and stays a block. An import line with no multi-line member
   list behaves exactly as today.

## Decisions

- **Absorb, don't merge.** The fix is not "join two intersecting blocks
  afterwards" — the braces block is never created. Merging after the fact
  would still expose a toggle on the inner lines during the transition, and
  `joinIntersecting` already declines to merge different block types.
- **All three pair characters, not just braces.** The parser treats `(`, `[`
  and `{` uniformly; the import rule is stated once for all of them rather
  than special-casing the brace. In practice only Scala's selective import
  uses it today.
- **Nested pairs inside an absorbed block are absorbed too.** A member list
  containing its own `(`…`)` must not re-open a block; the depth counter
  keeps the pairing correct.
- **The closing line is an import line.** So an import statement whose member
  list ends the file still produces one imports block, not a dangling one.

## Out of scope

- The indent-based fallback parser (`fallback_foldable_block_parser.dart`) —
  the gap is in the highlight parser.
- Renaming, reordering or otherwise changing the import sequence itself;
  multi-line `import` in other languages (Java has no such syntax).
- Changing `FoldableBlock`/`joinIntersecting`.

## Note for whoever edits the parser next

`tool/coverage_gate.py` pins `EXEMPT_LINES` by **line number**, including
entries in `lib/src/folding/parsers/highlight.dart` and `text.dart`. Any
insertion above an exempted line shifts it and the gate goes red with a
"matches nothing" or a bare miss. Renumber after the edit.

## Acceptance criteria

- [ ] A multi-line selective import folds as one `imports` block whose last
      line is the closing brace line; no braces block is reported for it.
- [ ] A member list containing its own pair characters produces no extra
      block.
- [ ] Single-line selective imports behave exactly as today (ignored as a
      single-line pair block).
- [ ] Pair blocks on non-import lines are unaffected — every existing Scala
      pair-character test still passes unchanged.
- [ ] An import statement ending at the last line of the file (no trailing
      newline) is covered.
- [ ] Coverage stays at the 100% gate; new branches are covered or proved
      dead.

## Gates

`flutter test` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
