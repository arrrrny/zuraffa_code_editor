# Research: highlight-cursor-line

Fork issue #113 / upstream #194. Four questions had to be answered before the
spec could be written; each is recorded with the evidence and the decision it
produced.

## R1 — is there already an offset→line conversion, or does this spec need one?

**Question.** #113's whole job is "given the caret's character offset, which line
is it on". If the package has no such conversion, the deliverable is bigger than
a colour field.

**Finding.** It exists: `CodeLines.characterIndexToLineIndex(int)`
(`lib/src/code/code_lines.dart:30`), a linear-interpolation binary search over
`CodeLine.textRange`. It is not internal plumbing — `Code` itself depends on it
to map a `TextRange` onto line numbers in four places:

- `code.dart:382-383` — `CodeLineRange` for a character range,
- `code.dart:487-488` — the first/last changed line of an edit,
- `code.dart:524-525` — the line range a text edit dirties,
- `code.dart:647` — a comment explaining that a folded block's lines resolve
  through it to `block.lastLine`.

Its contract: "`characterIndex` can be from 0 to length inclusive. If it is
equal to length, it means the cursor at the end of the text. Other values throw
`RangeError`."

**Decision.** Reuse it; add no helper. The one thing that must wrap it is a
range check, because `RangeError` inside a `build` method is fatal — see R4.

## R2 — does the tint follow the caret for free, or does the layer need a listener?

**Question.** `LineBackgroundLayer` is a `StatelessWidget` with no listener of
its own; it reads `controller.lineBackgroundBuilder` and `controller.code` when
it builds. If nothing rebuilds the field on a selection-only change, the
current-line tint would be pinned to whatever line the caret was on when the
field was first pumped, and the whole feature would need new plumbing.

**Finding.** `CodeController extends TextEditingController`
(`code_controller.dart:41`), so it *is* a `ValueNotifier<TextEditingValue>` and
notifies on every value change, including a selection-only one. `CodeField`'s
state subscribes to it in `initState`:

- `code_field.dart:362` — `widget.controller.addListener(_onTextChanged)`
- `_onTextChanged` ends at `code_field.dart:484` with `rebuild()`, which is
  `setState` (`code_field.dart:440-451`), guarded by `_isEditorBoxLaidOut`
  (`code_field.dart:432-436`) precisely because `setState` mid-frame throws.

So every selection change rebuilds `CodeField.build`, which re-reads the layer's
inputs. This is also exactly why #86's test `re-renders when the hook is
reassigned` (`per_line_background_test.dart:237-251`) works with a bare
`controller.notifyListeners()` and no new plumbing.

**Decision.** No new listener. The verification is behavioural, not by
inspection: tasks.md carries a test that moves the caret and asserts the tint
moved. If it goes RED, the plumbing is added then — and only then.

## R3 — how do the two hooks compose without breaking #86?

**Question.** #86's eleven tests pin the current behaviour, including
`leaves the field untouched when it is not set`, which asserts that **no**
`Stack` and **no** `LineBackgroundLayer` exist under `CodeField`
(`per_line_background_test.dart:82-101`). Widening the layer's gate to include
`currentLineColor` risks that test; widening it wrongly risks the
`returns null for every line` test, which expects the layer present but painting
nothing.

**Finding.** The layer's colour resolution is one expression per visible line
(`line_background.dart:55`), so composition is a `??` chain, not a restructure:

```dart
final color = lineBackgroundBuilder?.call(lineIndex) ??
    (lineIndex == currentLine ? currentLineColor : null);
```

and the gate at `code_field.dart:652-653` becomes a conjunction. Both existing
tests survive unchanged, because both set `currentLineColor` to its null
default:

- no hook at all → gate still false → no `Stack`, no layer. GREEN.
- hook returning null for every line → gate true, layer built, every row
  resolves `null ?? null` → `SizedBox` per row, no `Container`. GREEN.

**Decision.** Compose in the layer with a `??` chain, and widen the gate to
`lineBackgroundBuilder == null && currentLineColor == null`. The eleven #86
tests are the regression net and are run **unmodified** — a failure there means
the composition is wrong, not that the tests are stale.

## R4 — what caret states can break `characterIndexToLineIndex`?

**Question.** It throws `RangeError` outside `[0, text.length]`. Which real
states reach it with a value outside that range?

**Finding.** Three, all reachable:

1. **No selection.** `TextEditingValue`'s default selection is
   `TextSelection.collapsed(offset: -1)`. `text_editing_value.dart:172-203`
   bails out on `baseOffset == -1 || extentOffset == -1`, i.e. this repo knows
   about the sentinel and leaves it alone.
2. **A caret at the end of the text.** `extentOffset == text.length` is *valid*
   for the helper (documented as "the cursor at the end of the text"), so it
   must **not** be rejected.
3. **`code` lagging the value.** `code` is derived from the text; during a
   rebuild triggered by a text change, `controller.code.text` can be shorter
   than the incoming `selection.extentOffset` for the duration of one frame.
   The guard is written against `controller.code.text.length` — the same buffer
   the line indices come from — so it stays consistent with whatever
   `characterIndexToLineIndex` is about to search.

**Decision.** Compute the caret line once per build, behind a single guard, and
treat an out-of-range caret as "no current line":

```dart
final text = controller.code.text;
final offset = controller.selection.extentOffset;
final currentLine = offset >= 0 && offset <= text.length
    ? controller.code.lines.characterIndexToLineIndex(offset)
    : -1;
```

An unreachable index like `-1` can never match a visible line number, so no
extra branch is needed downstream. Each of the three states gets a test, because
each is a coverage-gate branch and a real crash if wrong.

## R5 — why a second field rather than making `lineBackgroundBuilder` default?

**Question.** #86 already has a hook that can express "tint the current line".
The alternative shapes are: (a) leave #86 alone and add a second field; (b) give
`lineBackgroundBuilder` a non-null default closure that follows the caret;
(c) have the layer call the builder and fall back to the caret tint, with no new
field at all.

**Finding.** (b) breaks #86's central invariant — "left null, the layer is not
in the tree at all" — and silently changes the rendered tree for every existing
host, which is a breaking change the issue does not ask for. (c) has no way for
the host to configure the colour: it would hard-code a tint, and a tint that
cannot be turned off is worse than one that does not exist.

**Decision.** (a) — one nullable field, null default, composed with the existing
hook. It is the smallest additive surface that makes the feature both
configurable and opt-out-able, and it keeps every #86 decision intact.

## Summary of what this spec deliberately does not reopen

- `LineBackgroundLayer`'s row geometry, gutter padding and scroll linking —
  already correct and pinned by #86's tests.
- The `Stack`-only-when-asked tree shape — preserved by widening the gate
  conjunctively.
- `lineBackgroundBuilder`'s signature — unchanged.
- The gutter — out of scope (see spec.md, Decisions).
