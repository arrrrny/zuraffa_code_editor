# Decision: no lazy loading / chunked rendering — the keystroke path is already
linear and its ceiling is architectural (#22)

**Issue:** [arrrrny/zuraffa_code_editor#22](https://github.com/arrrrny/zuraffa_code_editor/issues/22)
— synced from upstream `akvelon/flutter-code-editor#264`.
**Label:** `spec`

## Question

> Hi, I am developing a Flutter desktop application. The typing speed is reduced
> if we go for huge text. is there any way to add lazy loading or something else?

Upstream's answer, verbatim (`akvelon/flutter-code-editor#264`, maintainer
TheMultii):

> You would have to mostly rewrite the entire text editor in flutter to get a
> working lazy loading. It's also possible to split the TextField into many
> TextFields, but this is also difficult to implement, and has no advantages
> other than performance. […] There's not much you can do if Flutter's TextField
> is laggy when handling too many lines of text.

This spec measures what the keystroke actually costs on this fork, decomposes
it, and decides against the rewrite on the evidence.

## Measurement

One single-character insertion in the middle of a 3000-line Java-like document
(110 KB), measured through `CodeController`'s `value` setter — the whole
synchronous path a keystroke drives. `flutter test` (unoptimized JIT), median of
9 reps, after a warm-up rep:

| Component | µs | Share | What it is |
|---|---|---|---|
| `highlight.parse(text)` | 52,000–59,000 | ~62% | lexes the whole document; the `highlight` package exposes no incremental API (`Highlight.parse` always starts at offset 0 with full mode state) |
| `Code(...)` construction | 15,000–17,600 | ~18% | six whole-document passes: comment parse (1.9 ms), line building (2.9 ms), foldable-block matching (3.7 ms), hidden ranges, hidden line ranges, span splitting |
| `Autocompleter.setText` | 5,600–6,700 | ~7% | already incremental since #39; the remainder is `_splitWords` over the whole text |
| remainder | ~11,000 | ~13% | the `Code.getEditResult` diff (8 µs), tab replacement, selection mapping, `visibleText` compares, history |
| **setter total** | **~84,400** | 100% | |

Growth is linear in rows, not quadratic: the existing
`test/src/code_field/edit_latency_test.dart` measures 200 / 1000 / 3000 lines
and asserts the per-line cost at 3000 lines stays within 3× the per-line cost
at 200 lines; it passes at ~29 µs/line at every size.

## Decision: do not implement lazy loading

Three findings, each independently sufficient:

1. **The dominant cost cannot be made incremental without vendoring the
   highlighter.** `highlight.parse` lexes from offset 0 every call. The only
   correct reuse rule — the highlight of a prefix depends only on that prefix —
   lets a *stale* result be kept for the unchanged prefix, but producing the
   highlight for the changed tail still needs a full parse, because the lexer
   state at any offset is not exposed. That is a fork of `highlight`, not a
   change to this package.

2. **The `Code` model is immutable and rebuilt wholesale.** The `value` setter
   already computes an incremental edit result (`Code.getEditResult`, 8 µs) but
   uses it only to map the edit into the full text and to check read-only
   lines; every derived structure (lines, folds, hidden ranges, per-line spans)
   is rebuilt from the full text because each is a whole-document value. Making
   any of them incremental changes `Code`'s invariants and every consumer —
   the editor rewrite upstream described.

3. **The per-keystroke work is already linear and already trimmed where it
   could be.** #39 removed the three accidental O(n) terms (`Code.foldedAs`'s
   re-split, `cutHighlighted`'s copy, the autotrie re-entry); what is left is
   the irreducible O(n) model. Splitting one `TextField` into many would move
   the bottleneck into Flutter's engine, where the reported lag lives
   (flutter/flutter#128575, flutter/flutter#90063) and where this package
   cannot reach.

## Deliverable

The measurement, preserved where the next contributor looks for it: the
decomposition table above is recorded as the doc comment of
`test/src/code_field/edit_latency_test.dart`, next to the linearity assertion
that is the regression guard. No production code changes.

The guard: the per-line keystroke cost at 3000 lines within **2×** the per-line
cost at 200 lines. Unmodified it measures 1.0–1.3 (five consecutive runs: 1.08,
1.01, 1.09, 1.25, 1.11), because a keystroke's work is linear in rows. The
bound was 3× before this PR and was tightened on the evidence above.

Fault-injected to validate the tightened bound:

| Injected fault | Measured ratio | Reddens? |
|---|---|---|
| an O(rows²) pass in `CodeLinesBuilder.textToCodeLines` — one full walk of the lines per line, +29 µs/line at 3000 lines | 2.13× | yes |
| reverting #39's `Autocompleter` fix — re-entering every word per keystroke | ~1.1× (within noise; 83.6 ms vs 91.8 ms at 3000 lines) | no — it is linear |
| reverting #39's `cutHighlighted` copy — rebuild the highlight tree whenever nothing is hidden | ~1.0× (84.6 ms vs 91.8 ms) | no — it is linear |

The two reverts are the honest half of the table: they are O(n) constant terms,
so no linearity bound can see them, and at 3000 lines they are noise next to
`highlight.parse`. The guard exists for the term that is not linear, and the
injected quadratic is what such a term looks like.
