# Plan: scala multiline imports

**Spec:** ./spec.md
**Issue:** [arrrrny/zuraffa_code_editor#117](https://github.com/arrrrny/zuraffa_code_editor/issues/117) (upstream `akvelon/flutter-code-editor#78`)
**Label:** `spec`

## Design

The parser already knows both halves of the answer; they just never meet. The
pair-character machinery in `highlight.dart` opens a braces block on the `{`
of an import line; the import-sequence machinery in `text.dart`/`abstract.dart`
groups lines whose semantic is `import`/`possibleImport`. This plan makes the
two talk to each other.

### 1. `lib/src/folding/parsers/text.dart` — the depth flag

```dart
/// > 0 while inside a pair-character block that opened on a line with import
/// semantics; such lines continue the import sequence instead of terminating
/// it.
int _importPairBlockDepth = 0;

@protected
void enterImportPairBlock() => _importPairBlockDepth++;

@protected
void exitImportPairBlock() => _importPairBlockDepth--;
```

`submitCurrentLine` grows one arm, placed after the terminator arm and before
the possibleImport arm (both would submit `possibleImport` anyway):

```dart
if (_importPairBlockDepth > 0) {
  _endCommentSequence();
  _submitLineSemantics(LineSemantics.possibleImport);
  return;
}
```

The depth is parser state, not a per-line flag: it is NOT cleared by
`clearLineFlags()` — it must survive across newlines until the block closes.

### 2. `lib/src/folding/parsers/highlight.dart` — absorb the block

At each open pair character, absorb when the current line carries import
semantics or we are already inside an absorbed block:

```dart
case $openParenthesis: // (
case $openBracket: // [
case $openBrace: // {
  if (foundImport || _importPairBlockDepth > 0) {
    enterImportPairBlock();
  } else {
    startBlock(lineIndex, <matching type>);
  }
  break;
```

The matching close exits absorbed blocks (and marks the closing line as an
import line) or ends a regular block:

```dart
case $closeParenthesis: // )
case $closeBracket: // ]
case $closeBrace: // }
  if (_importPairBlockDepth > 0) {
    exitImportPairBlock();
    setFoundPossibleImport(); // the closing line continues the sequence
  } else {
    endBlock(lineIndex, <matching type>);
  }
  break;
```

Because the three pair cases in `_processDefaultValue` currently repeat,
this is a good moment to factor the open/close handling into small private
helpers — but only if `dart format`/analyze stay clean; the duplication in
place is acceptable if the shape fights back.

### Why this shape and not the alternatives

- **Not `joinIntersecting`.** It declines different types anyway; and a
  braces block that exists and is then merged is still a toggle the user sees.
- **Not a post-pass over `blocks`.** The information "this block opened on an
  import line" is only exact at the moment the block opens; reconstructing it
  afterwards means re-deriving line semantics.
- **Not touching `endImportSequenceIfAny`.** Its gap check is correct for
  real gaps; the imported lines were never missing — they carried the wrong
  semantic. Fixing the semantic is the smaller, more local change.

## Order of work

1. `test/src/folding/parsers/highlight_parser_scala_test.dart` — flip the
   TODO-pinned test to expect one `imports` block, add the nested-pair,
   no-trailing-newline and absorbed-multiline-comment cases. Red.
2. `text.dart`: the depth field, its two mutators, the new `submitCurrentLine`
   arm.
3. `highlight.dart`: absorb at open, exit at close.
4. Full folding suite, then the whole suite, coverage gate.

## Risks

- **Depth leaks across languages.** The rule fires only when a pair opens on
  an import line; Java/Python/Go have no such syntax, so their suites are the
  regression guard. The java, python, go, markup, indent and fallback tests
  run unchanged.
- **Mismatched pairs inside an absorbed block** (`import a.{ b }` with a stray
  `)`): depth still balances for the balanced prefix; degenerate input may
  absorb one extra block. No existing test constructs that inside an import;
  noted, not pinned.
- **`EXEMPT_LINES` in `tool/coverage_gate.py` pins lines 93 (highlight.dart)
  and 27/28/49/79/80 (text.dart) by number.** text.dart changes shift lines
  above 27/28 — count the inserted lines and renumber before the gate.
- **The closing line sets `setFoundPossibleImport()` after `exitImportPairBlock`
  returns depth to 0** — the flag must be set on exit, not before, or the
  closing line would submit through the new arm before the depth check that
  would then... actually either order reaches `possibleImport`; exit-then-flag
  is chosen because the flag is what a line that *closed* an import block
  means, and it reads as one unit. Pin it with the no-trailing-newline test.
