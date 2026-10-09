# Spec: paste-service-comments-cursor

## Goal

After pasting code that contains service comments (`// [START …]` /
`// [END …]`), the caret must sit at the end of the pasted run — not near its
start.

## Requirements

1. When the framework hands `CodeController` a `TextEditingValue` whose text is
   longer than the resulting `_code.visibleText` **and** whose selection is
   collapsed, the caret is the round-tripped one:
   `recoverSelection(newValue.selection)` into the full text, then
   `cutSelection` back into the re-derived visible text. The framework's own
   caret offset is preserved.
2. When the selection is **not** collapsed in that same branch, behaviour is
   unchanged: `newValue.replacedText(_code.visibleText)` (caret collapses to
   the start of the newly hidden text).
3. When `newValue.text.length < _code.visibleText.length` (a folded block got
   unfolded), behaviour is unchanged.
4. `fullText` after the paste contains the pasted content in full.
5. No existing pinned behaviour changes — specifically the three existing
   tests that guard this branch (typed-in service comment, deleting a folded
   block, unfolding).

## Non-goals

- No change to `recoverSelection` / `cutSelection` / `replacedText` semantics.
- No change to the fold/unfold caret logic.
- No change to how hidden ranges are discovered.

## Test plan

`test/src/code_field/code_controller_paste_hidden_test.dart` (new, 3 tests):

| Test | Master | Purpose |
|------|--------|---------|
| caret lands at the end of the pasted run | **RED** (60, expected 92) | the bug |
| caret lands after the pasted run when it is inserted mid-text | pass | guard: no hidden range introduced, caret still follows the run |
| the pasted text reaches fullText in full | pass | guard: the paste is not truncated |

## Definition of done

- RED → GREEN on the caret test; the two guards stay green on master.
- Full suite 366/366, `dart analyze` clean, `dart format` clean.
- Artifacts under `.specify/bugs/paste-service-comments-cursor/` and `tdd/`.
