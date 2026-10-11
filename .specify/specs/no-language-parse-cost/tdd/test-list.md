# Test list: pin the cost of the keystroke path when no language is selected

Fork issue: #111 · Spec: `.specify/specs/no-language-parse-cost/spec.md`

The deliverable is a decision with evidence, not new behaviour. Every test is
green on the unfixed tree — that is the finding. What the tests buy is that the
finding stays true: each one is written so that it *can* fail, and the fault
injections below prove they do.

## Outer loop — acceptance criteria (behaviours observable by a user)

### behavior: US1-AC1 — a keystroke with no language completes in the tens of milliseconds

`No language selected does not make a keystroke expensive`
(`test/src/code_field/no_language_keystroke_test.dart`)

Builds a 4800-line document, a controller with no language and a controller with
`java`, and measures the median of 5 keystrokes on each (single character
inserted mid-document, exactly the shape `edit_latency_test.dart` measures).

Asserts, in order:

1. `noLanguageKeystroke < 100_000 µs` — SC-002 / FR-002. Measured
   13 100–14 475 µs, ~7× headroom.
2. `noLanguageKeystroke <= javaKeystroke` — SC-003. Measured ratio 0.105–0.117.
3. `noLanguageParse < javaParse * 0.05` — SC-001 / FR-004. Measured
   10–18 µs against 78 882–96 509 µs, i.e. 0.013–0.021% — ~4 500× headroom.
4. `noLanguageKeystroke / javaKeystroke < 0.6` — SC-004, the tripwire. Measured
   0.105–0.117, ~5× headroom. The bound is deliberately loose for machine noise
   and deliberately far below 1 for the regression it exists to catch.

### behavior: US1-edge — an unresolvable language is exactly like no language

`An unresolvable language name costs the same as no language at all`
(same file) — FR-003, the spec's first edge case.

Measures `highlight.parse` under the empty id and under a name that is neither a
registered language nor a registered alias, and asserts the two medians agree
within 2×. This is the assertion that would catch a fallback change from
`?? plaintext` to auto-detection: auto-detection would parse with every
registered language, which is two orders of magnitude more work.

## Inner loop — the mechanism, verified rather than assumed

No unit behaviour is added under `lib/`, so there are no inner-loop units. The
mechanism the behaviour rests on is verified in the dependency, not the package:

- `highlight-0.7.0/lib/src/highlight.dart:271` — `_getLanguage(language) ?? plaintext`
- `highlight-0.7.0/lib/src/highlight.dart:497-501` — `_getLanguage` returns null
  for an unknown name
- `highlight-0.7.0/lib/languages/plaintext.dart:6` — `Mode(refs: {}, disableAutodetect: true)`
- `lib/src/code_field/code_controller.dart:97` and `:274` — `_languageId` is `''`
  until `setLanguage` assigns it

## Measured, five consecutive runs

```text
highlight.parse  no language: 10 / 11 / 11 / 14 / 16 / 18 us
highlight.parse  java:        81604 / 81074 / 96509 / 80681 / 78882 / 87821 us
keystroke median  no language: 13139 / 13986 / 14475 / 13871 / 13941 / 14060 us
keystroke median  java:        127246 / 123692 / 129519 / 122746 / 124255 / 128465 us
paste median      no language: 16096 / 16569 / 16602 / 17044 us
paste median      java:        124787 / 127422 / 128335 / 129234 us
```

## Fault injections (all measured on this machine)

| Fault | Result |
|---|---|
| `highlight.registerLanguage('', java)` before measuring the no-language path — the shape of a fallback that resolves to a real language | parse 80 532 µs vs with-language 76 120 µs (ratio 1.06), keystroke 109 045 µs, parse share 73.9% → **RED** on SC-002 (100 000 µs bound) and on SC-001 (3 806 µs budget) |
| nothing (unmodified tree) | 10–18 µs parse, 13.1–14.5 ms keystroke → **GREEN** on all four |

SC-003 alone survives the injection, because the two paths then genuinely do the
same work. That is why the tripwire is SC-001 + SC-002 + the ratio, not the
ordering.

### behavior: US1-paste — a paste of a large document with no language does not block

`Pasting a large document with no language does not block` (same file) — the
acceptance criterion of fork #93, whose report (upstream #246, the same report
as #111) is specifically about a paste: "4800+ lines of output into the editor".

Builds an empty controller with and without a language, assigns the whole
4800-line document through the `value` setter (a fresh controller per rep, so
each rep pays the same whole-document terms), and medians 5 reps after a
warm-up rep.

Asserts:
1. `noLanguagePaste < 1_000_000 µs` — "does not block for seconds". Measured
   16.1–17.0 ms; the bound is a full order of magnitude of headroom so a CI
   machine several times slower still passes.
2. `noLanguagePaste <= javaPaste` — the no-language paste is not slower than the
   highlighted one. Measured 16.1–17.0 ms against 124.8–129.2 ms.

## Existing suites that pin the unchanged behaviour (no new tests)

- `test/src/code_field/edit_latency_test.dart` — the per-line linearity guard
  for the with-language path (#22). Unchanged and untouched; this feature adds
  the no-language leg that linearity cannot see.
- The full suite: no `lib/` change ships, so every other test is unaffected.
