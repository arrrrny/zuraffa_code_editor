# TDD verification: highlight-cursor-line

Feature: `.specify/specs/highlight-cursor-line-113/` · Fork issue #113 ·
Upstream `akvelon/flutter-code-editor#194`

This is the evidence trail, not a summary of the code. Every claim here was
produced by a command in this worktree, and the numbers are what the commands
printed.

## RED first

`test/src/code_field/current_line_highlight_test.dart` was written in full before
any implementation change, and run:

```
flutter test --concurrency=2 test/src/code_field/current_line_highlight_test.dart
```

RED, and RED for the right reason — the field did not exist:

```
Error: The setter 'currentLineColor' isn't defined for the type 'CodeController'.
  test/src/code_field/current_line_highlight_test.dart:239:18
  test/src/code_field/current_line_highlight_test.dart:356:18
  test/src/code_field/current_line_highlight_test.dart:373:18
  test/src/code_field/current_line_highlight_test.dart:389:18
00:00 +0 -1: Some tests failed.
```

Then T006–T008 were written, and the same command went GREEN on the first
attempt: `00:08 +16: All tests passed!`

## Test inventory

`test/src/code_field/current_line_highlight_test.dart`, 16 tests:

| Test | Acceptance criterion |
|---|---|
| tints the caret's row when it is the only hook set | FR-002 |
| leaves every other row untilted | FR-003 |
| follows the caret when the selection moves | FR-004 |
| follows the caret while typing | FR-004 |
| follows the caret when a line is tapped | FR-005 |
| tints only the caret's line when a selection spans several | FR-006 |
| renders and tints nothing with no selection at all | RB-001 |
| tints the last line when the caret is at the end of the text | RB-002 |
| tints nothing when the caret's line is no longer rendered | FR-007 |
| keeps tinting the caret's line when a fold opens elsewhere | FR-007 |
| composes: the host builder wins and the caret still tints | FR-008 |
| composes: the host builder wins even on the caret's line | FR-008 |
| leaves the field untouched when neither hook is set | FR-009 |
| still works when no language is set | NR-002 |
| re-renders when the colour is reassigned | NR-003 |
| takes the layer back out of the tree when the colour is cleared | FR-009 |

Three of these started out wrong and were corrected rather than the
implementation bent to fit them, which is worth recording because each was a
real contract discovery:

- A fold of a block over lines 0–2 leaves **line 0 rendered** — #86's own test
  `does not ask about a line hidden inside a folded block` already asserted
  `seen == [0, 3]`. So "the caret's line is folded away" cannot be tested by
  putting the caret on line 0. The test now pins the actual rule: the tint is on
  the caret's line whenever that line is among the rendered lines, and on nothing
  at all when it is not, which holds whatever the fold did to the caret.
- Clearing the last remaining hook takes the `LineBackgroundLayer` **and** the
  `Stack` out of the tree, rather than leaving a layer that paints nothing. That
  is the correct reading of the tree-shape guarantee, and the test asserts it.
- `tester.tap(find.byType(TextField))` lands at the field's **centre**, which in
  this four-line fixture is line 2, not line 0. The typing test asserts the tint
  followed the tap there, then that it followed the caret to line 1 after
  `enterText`.

## Regression net

#86's eleven tests, run **unmodified**:

```
flutter test --concurrency=2 test/src/code_field/per_line_background_test.dart
00:07 +10: All tests passed!
```

Run together with the new file, all 26 pass:

```
flutter test --concurrency=2 test/src/code_field/current_line_highlight_test.dart \
    test/src/code_field/per_line_background_test.dart
00:05 +26: All tests passed!
```

## Mutation audit

Five mutants, each applied to the real source, run against the new test file,
then restored. The script asserts each restored file's SHA-256 matches its
pre-mutation digest, and prints it:

```
=== M-useBaseOffset === KILLED
=== M-dropGuard === KILLED
=== M-invertChain === KILLED
=== M-hardcodeZero === KILLED
=== M-disjunctiveGate === KILLED
all originals restored byte-identical: True
summary: 5/5 killed
```

| Mutant | Change | What kills it |
|---|---|---|
| `M-useBaseOffset` | `selection.extentOffset` → `selection.baseOffset` | `tints only the caret's line when a selection spans several` — the anchor's line is tinted instead of the caret's |
| `M-dropGuard` | drop the `offset < 0 \|\| offset > text.length` check | `renders and tints nothing with no selection at all` throws `RangeError` from `characterIndexToLineIndex`; `tints the last line…` fails too |
| `M-invertChain` | `(line == currentLineIndex ? currentLineColor : null) ?? builder?.call(line)` | both compose tests — the caret colour overwrites the host's answer |
| `M-hardcodeZero` | `currentLineIndex = 0` | every caret-move test |
| `M-disjunctiveGate` | `&&` → `||` in the layer gate | the layer never enters the tree, so every test dies with `RangeError` on an empty row list |

`M-disjunctiveGate` looked like a weak kill at first — the audit run reported
only a load failure — so it was re-run by hand and the failures confirmed to be
behavioural, not compilation:

```
Expected: an object with length of <1>
  Actual: []
The following RangeError was thrown running a test:
RangeError (length): Invalid value: Valid value range is empty: 1
```

With `||`, a field that sets only `currentLineColor` resolves the gate to `true`
and takes the `editingText` branch, so the layer never exists at all.

## Static gates

```
dart analyze --fatal-infos
Analyzing zuraffa_113...
No issues found!

dart format --output=none --set-exit-if-changed .
Formatted 305 files (0 changed) in 0.92s.
```

One analyzer warning was raised during development and fixed rather than
suppressed: an unused local `controller` in the typing test, which had been
keeping a `FocusNode` the widget never used. The test now focuses the field the
way the rest of the suite does — `tester.tap(find.byType(TextField))` — which is
also what surfaced the centre-of-field discovery above.

## Coverage gate

CI-identical procedure from `quickstart.md` §3, run against the final committed
tree on `spec/highlight-cursor-line-113` rebased onto `31ac3de` (the merge of
#87, so the number is the tree the PR actually proposes):

```text
All tests passed!                                     (874)
zuraffa_code_editor line coverage: 100.00% (3527/3527 lines over 109 files)
excluded individual lines (see EXEMPT_LINES): 9
Coverage gate: 100.00% >= 100.00% -- OK
```

**874** = the 16 new tests plus everything already on master. **No exemption was
added and no line was exempted for this feature**: the 9 `EXEMPT_LINES` are
pre-existing, and the count is unchanged from master's, so every line this branch
adds is covered by a test rather than by an exemption. The `3527` total is
master's `3518` plus the 9 lines of new logic in `line_background.dart`.

## Scope confirmation

- No gutter or line-number tint was added.
- `lineBackgroundBuilder`'s signature, call order and coordinate space are
  unchanged.
- No new public type, no new export; `LineBackgroundLayer` remains `@internal`.
- No listener was added. `M-*` evidence covers the behaviour, and the caret is
  followed through `CodeController`'s existing `ValueNotifier`
  notification → `_onTextChanged` → `rebuild()` path, which
  `follows the caret while typing` exercises end to end.
