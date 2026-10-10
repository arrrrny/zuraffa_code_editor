# Bug Spec: Sluggish performance past a few hundred rows

- **Slug**: performance-hundred-rows
- **Issue**: 39 (upstream `akvelon/flutter-code-editor#255`)
- **Severity**: medium — the editor is usable but typing falls behind the user
- **Platform**: all

## Symptom

Upstream reports "Performance issues can occur if the number of rows exceeds a
few hundred. Very sluggish." No profiler output, no platform, no file — so the
first job here is to turn the sentence into numbers.

## What was measured

`flutter test` runs the VM JIT in debug mode, so a benchmark there reads about
an order of magnitude above a release build — but the *shape* is what matters,
and the shape is the same. Measured on this branch, median over 8 keystrokes
after a warm-up, one character inserted in the middle of a Java-like document:

| lines | median keystroke |
|---|---|
| 200 | 7.6 ms |
| 1000 | 28.6 ms |
| 3000 | 88.7 ms |

Growth is linear in rows, not super-linear: the per-line cost is flat
(38 µs at 200 lines, 30 µs at 3000). So the report is not a quadratic algorithm
— it is a large linear constant, and at 3000 rows that constant is tens of
milliseconds per keystroke. That is the sluggishness, and it is why the
acceptance criterion "growth is sub-linear" is recorded here as not met: there
was never a super-linear term to remove.

Where that constant goes, measured two ways — temporary `Stopwatch`
instrumentation of the edit path, and isolated measurements of the same steps
inside the same harness. Both agree on the shape:

| step | share of a keystroke |
|---|---|
| `highlight.parse` of the whole document (`CodeController._createCode`) | ~57-61% |
| the rest of `Code(...)` — comment, foldable-block and line parsing | ~17-18% |
| a second `cutHighlighted` + `splitLines` of the tree (`Code.foldedAs`) | ~6-10% |
| `Autocompleter.setText` — re-indexing every word of the document | ~9-12% |

Absolute milliseconds are not quoted for these: they move by up to 2x between
harnesses on the same machine depending on how much garbage the harness has
already produced, while the shares hold. The end-to-end table in `fix.md` is the
authoritative number.

## Scope

1. Stop rebuilding the visible highlight tree twice per keystroke.
2. Stop re-indexing the whole document into the autotrie on every keystroke.
3. Capture the latency against row count as a committed benchmark so the next
   regression of this kind is caught by CI rather than by a user.

## Out of scope

- `highlight.parse`. It is the single largest cost and it is linear and
  irreducible without an incremental highlighter; the package has no seam to
  parse only the changed region. Noted in `fix.md` as the remaining ceiling.
- Lazy per-line highlighting (the subject of fork issue #22), which would be
  the change that removes the parse cost, but is a different design.
