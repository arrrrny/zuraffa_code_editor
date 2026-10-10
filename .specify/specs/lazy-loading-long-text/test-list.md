# Test list — lazy loading / chunked rendering decision (#22)

The deliverable is a decision with evidence, not new behaviour. The regression
guard is the pre-existing linearity pin, tightened from 3× to 2× on the
measured evidence.

1. `A keystroke gets no more expensive per line as the document grows`
   (`test/src/code_field/edit_latency_test.dart`) — the acceptance criterion of
   this spec. Measures the median cost of one single-character keystroke at
   3000, 1000 and 200 lines and asserts
   `perLine(3000) < perLine(200) * 2`. GREEN on the current code, where the
   ratio measured 1.01–1.25 over five consecutive runs.

   Fault injections, all measured on this machine:

   | Fault | Ratio | Result |
   |---|---|---|
   | O(rows²) pass in `CodeLinesBuilder.textToCodeLines` (one full walk of the lines per line; +29 µs/line at 3000 lines) | 2.13× | **RED** |
   | revert #39's `Autocompleter` incremental index (re-enter every word per keystroke) | ~1.1× | green — linear |
   | revert #39's `cutHighlighted` copy (rebuild the tree when nothing is hidden) | ~1.0× | green — linear |

   The two reverts are linear constant terms and stay invisible to any
   linearity bound — at 3000 lines they are noise next to `highlight.parse`.
   The tightened bound catches the term that is not linear, which is the class
   of regression this guard exists for.

2. No new behavioural tests. The spec's finding is that the keystroke path is
   already linear and its three whole-document terms cannot be trimmed without
   an architectural rewrite (issue #22 asks for lazy loading; upstream
   `akvelon/flutter-code-editor#264` declined it for the same reason). The
   decomposition of one keystroke is recorded as the doc comment of the latency
   test, because asserting any share of it as a test would be a machine-clock
   budget: `highlight.parse` ~62%, `Code(...)` ~18%, `Autocompleter.setText`
   ~7%, remainder ~13%.
