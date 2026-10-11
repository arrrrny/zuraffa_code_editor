# Verification — no-language keystroke cost (#111 / #93)

**Feature**: `.specify/specs/no-language-parse-cost/spec.md`
**Audited**: branch `spec/no-language-parse-cost` @ `13e4161` (on top of
`master` @ `a02539a`)
**Engine**: `zfa` unavailable (`ZFA_MISSING` — no `.zfa.json`), so this is the
LLM-guided audit per `speckit-tdd-verify`'s fallback path.

## Verdict: PASS_WITH_GAPS

TDD discipline and test strength are proven for what this feature is: a pin, not
a behaviour change. The gaps are inherent to a decision feature and are recorded
rather than papered over.

## Test-first evidence

| Phase | Evidence |
|---|---|
| Feature branch | `spec/no-language-parse-cost`, created by the mandatory `before_specify` hook (`speckit.git.feature`) before the spec was written |
| Spec before plan | `spec.md` committed in `4335288`, ahead of `plan.md`/`research.md` |
| Test list before test | `tdd/test-log.md` → `tdd/test-list.md` committed in `d3465fc`, before the test file it describes landed in the same commit |
| Red-phase evidence | **Not present, and not obtainable** — see "Gaps" |

## Red-phase evidence and what replaces it

The usual red-first step could not be performed: the feature's finding is that
the reported behaviour does not exist. A red would have required demonstrating
that the editor is slow with no language selected, which measurement contradicts
(13–23 ms against 119.9–129.5 ms with a language).

What replaces it is **mutation evidence** — the property a red is used to
establish. Four mutants were injected on scratch copies
(`test/tmp_mutant_*_test.dart`), each measured and then deleted; none was
committed:

| # | Mutant | Injected into | Result |
|---|---|---|---|
| M1 | `highlight.registerLanguage('', java)` before the keystroke measurement — the no-language path resolves to a real language | test 1 | **KILLED** — no-language parse 80 532 µs vs with-language 76 120 µs (ratio 1.06), keystroke 109 045 µs, parse share 73.9%; reddens SC-002 (100 000 µs bound) and SC-001 (3 806 µs budget) |
| M2 | `highlight.registerLanguage('not-a-language-that-is-registered', java)` — an unresolvable name resolves to a real language | test 2 | **KILLED** — unresolvable parse 82 119 µs against the 4 305.8 µs budget |
| M3 | `highlight.registerLanguage('', java)` before the paste measurement | test 3 | **KILLED** — no-language paste 136 100 µs vs java 138 306 µs, ratio 0.984 against the 0.5 bound |
| M4 | Nothing (unmodified tree) | all | **GREEN** — 3/3 tests, three consecutive runs |

M3 exposed a genuine weakness that the audit then closed: the paste test's
original two assertions (`< 1 s` absolute, `<= javaPaste`) both survive a mutant
that makes the no-language paste pay for lexing. A ratio bound
(`noLanguagePaste / javaPaste < 0.5`, measured 0.125–0.136) was added, after
which M3 dies. The audit's remediation loop is therefore: 1 finding, 1 fix,
verified by re-injection.

## Test-smell rubric

| Smell | Finding |
|---|---|
| Assertion-free / print-only test | No — every test asserts |
| Sleep-based timing | No — `Stopwatch` around synchronous work |
| Wall-clock absolute budget as the only bound | No — ratios carry the tripwires; the two absolute bounds (100 ms keystroke, 1 s paste) are order-of-magnitude headroom over the measured 13–23 ms and 16–22 ms, and are what rules out the absolute stall the issue reports |
| Order-dependent hidden state | Fixed — each test builds its own `java` controller rather than relying on another test having registered the language on the process-wide `highlight` instance |
| Flaky microsecond comparison | Found and fixed — the unresolvable-name test originally compared two ~10 µs medians with a 2× window and failed on the full suite under concurrent load; it is now anchored on the ~79 ms with-language parse |
| Shared-helper default change | Avoided — `test/src/common/create_app.dart` defaults `language ?? java` and was deliberately left alone |
| Assertions on a `lib/` behaviour this feature does not change | No — no `lib/` change ships, which `git diff master -- lib/` confirms is empty |

## Acceptance-criteria coverage

| Criterion | Covered by | Status |
|---|---|---|
| SC-001 — no-language parse < 5% of with-language | test 1, `expect(noLanguageParse, lessThan(javaParse * 0.05))`; test 2 for the unresolvable name | 10–18 µs vs 78.9–96.5 ms |
| SC-002 — no-language keystroke < 100 ms | test 1, `expect(noLanguageKeystroke, lessThan(100 * 1000))` | 13.1–23.2 ms |
| SC-003 — no-language keystroke ≤ with-language | test 1, `expect(noLanguageKeystroke, lessThanOrEqualTo(javaKeystroke))`; test 3 for the paste | 0.125–0.136 ratio |
| SC-004 — a change making the no-language parse comparable fails the suite | test 1 ratio bound (0.105–0.166 vs 0.6 bound) + test 2's 5% bound + test 3's paste ratio bound (0.125–0.136 vs 0.5) | M1/M2/M3 killed |
| FR-003 — unresolvable name == no language | test 2 | both < 5% of with-language |
| #93's "a test pins the cost ... rather than wall clock" | test 3 | paste medians pinned |

## Suite and gate

- Full suite on the audited tip: **734 tests, all green** (731 on `master`
  @ `a02539a` + 3 new).
- `dart analyze --fatal-infos`: no issues.
- `dart format --set-exit-if-changed .`: clean.
- Coverage gate (`tool/coverage_gate.py --min 100`): **100.00% (3360/3360 lines
  over 105 files)** — the new test only exercises existing `lib/` lines, so it
  cannot lower the number.

## Gaps (recorded, not papered over)

1. **No red-phase commit.** Inherent to a decision feature. Replaced by four
   measured mutants, three of which kill the pin.
2. **No mutant that survives and drives remediation on a `lib/` behaviour**,
   because no `lib/` behaviour changes. The mutation surface is the `highlight`
   fallback, which lives in the dependency and was mutated through the `highlight`
   registry instead.
3. **The absolute bounds are machine-dependent by construction.** The 100 ms
   keystroke and 1 s paste bounds carry ~10x headroom over the measured values
   and are the parts of the pin most likely to fail on a much slower runner. The
   ratio bounds, which are the durable guards, are unaffected.
