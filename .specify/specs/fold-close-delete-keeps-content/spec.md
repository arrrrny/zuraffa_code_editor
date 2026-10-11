# Spec: deleting a folded block's closer keeps its content

Fork issue: #98 · Upstream: akvelon/flutter-code-editor#176, #175
Label: `bug` · Severity: `high` · Backlog rank: 1

## What was asked

Upstream #176/#175 report that editing around a folded block leaves the hidden
range in place, so text visualises glued or stays hidden.

## What exists today

The "range vanishes" symptom does not reproduce on this fork: adjacent
single-char and range deletions re-anchor the hidden range correctly. What
does reproduce is silent data loss. With

```
int a;
{
int b;
}


int c;
```

and the block folded, the visible text is `int a;\n{}\n\n\nint c;\n` and the
block's body is hidden as `HiddenRange(8, 16)`. Backspacing the visible `}` —
the block's closer, the first visible character after the hidden range — used
to produce

```
int a;
{
(blank)
(blank)
int c;
```

`int b;` is gone from the document. One visible character was deleted and one
hidden line was destroyed with it.

## Root cause

`Code.getEditResult` recovers the start of the replaced range with
`TextAffinity.downstream`. At a hidden range's collapse point that returns the
range's *start*, so the recovered replacement range covers the hidden content
and `rangeBefore.textBefore`/`textAfter` splice it out of the document. The
single-char deletion guard does not catch this shape: the diff's end lands on
the block's last line, and the guard requires that line to be *strictly*
inside the diff (the case it was written for is deleting the newline that
terminates the block, upstream #232, which is a deliberate no-op).

## What this spec adds

An edit whose first removed character is the first visible character after a
hidden range **owned by a folded block** recovers its start with
`TextAffinity.upstream` — after the hidden content — so only the removed
characters are spliced out and the body survives. The guard is keyed on what
the edit removes, not on the direction the visible text's length moved, so a
backspace and a replacement that grows the text (selecting the closer and
typing `} else {` over it) are both protected; the latter used to splice the
body out as well. A pure insertion at that point removes nothing and keeps
the downstream recovery, which is the documented insertion-side behaviour.
A hidden range no folded block owns (a named section's marker comment) keeps
the downstream recovery: deleting the marker instead of the adjacent
character is the documented behaviour for those, pinned by
`code_controller_hidden_ranges_test.dart`.

The ownership test is the folded block's own line span: a hidden range belongs
to a folded block when a `foldedBlocks` entry has the same `firstLine` and
`lastLine`. That is precise — folds and section markers are produced by
different machinery — and needs no new field on `HiddenRange`.

After the fix the backspaced closer yields

```
int a;
{
int b;


int c;
```

: the brace is gone, the body survives, and the block releases (there is no
closer left to fold), so the body becomes visible.

## What this spec does not change

- The single-char guard stays as written: backspacing the newline immediately
  after a folded block remains a no-op (upstream #232, pinned by
  `code_controller_set_value_test.dart`).
- Edits that do not begin with a removal at a hidden range's collapse point
  are unaffected: the two affinities only differ there.
- Named-section edits at a marker's collapse point still delete the marker.
