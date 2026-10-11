# Test list: fold-close-delete-keeps-content

Fork issue: #98 · Spec: `.specify/specs/fold-close-delete-keeps-content/spec.md`

Every test starts red. The order below is the red → green order.

## New file: `test/src/code/code_fold_close_delete_test.dart`

Shared harness: `Code` over `int a;\n{\nint b;\n}\n\n\nint c;\n` parsed as
java with `BracketsStartEndNamedSectionParser`, folded at line 1, so the
visible text is `int a;\n{}\n\n\nint c;\n` and the body is
`HiddenRange(8, 16, firstLine: 1, lastLine: 3)` — the same span as
`FoldableBlock(1, 3)`.

### The defect

1. Backspacing the closer — cursor after `}`, one character removed — keeps
   the body: `fullTextAfter` is `int a;\n{\nint b;\n\n\n\nint c;\n` (the four
   newlines that surrounded the brace stay; only the brace goes).
2. The same edit as a non-collapsed selection over the closer alone: same
   expectation.
3. A selection over the closer and the following newline deletes both and
   keeps the body: `int a;\n{\nint b;\n\n\nint c;\n`.

### The defect's replacement shape

4. Selecting the closer and typing `} else {` over it — the visible text
   grows — keeps the body: `int a;\n{\nint b;\n} else {\n\n\nint c;\n`.
5. Selecting the closer and typing `}}` over it keeps the body:
   `int a;\n{\nint b;\n}}\n\n\nint c;\n`.

### Red → green evidence

All three defect tests failed on the unfixed tree with the body spliced out
(`int a;\n{\n\n\nint c;\n` for 1 and 2, `int a;\n{\n\nint c;\n` for 3) — the
mutation is the shipped behaviour, so the tests provably can fail. The two
replacement tests above failed the same way on the tree whose guard was
length-gated, which is why the guard is keyed on the removed range instead
of the length direction.

### The boundary that stays downstream

6. A pure insertion at the collapse point — cursor before `}`, `x` typed —
   removes nothing and keeps the downstream recovery, so the text lands
   right after the opener: `int a;\n{x\nint b;\n}\n\n\nint c;\n`. This pins
   the insertion-side semantics the removal-keyed guard must not disturb.

## Existing suites that pin the unchanged behaviour (no new tests)

- `test/src/code_field/code_controller_hidden_ranges_test.dart` — forward
  delete at a named section's collapse still deletes the marker, not the
  adjacent character (the `downstream` recovery a no-fold range keeps).
- `test/src/code_field/code_controller_set_value_test.dart` — backspace of
  the newline immediately after a folded block is still a no-op (upstream
  #232).
- The full suite: every other edit around hidden ranges is byte-for-byte
  unchanged, because the two affinities differ only at a collapse point.
