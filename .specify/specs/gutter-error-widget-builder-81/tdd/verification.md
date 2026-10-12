# TDD Verification: gutter-error-widget-builder-81

Audited: 2026-10-12 · Engine: raw (LLM-guided audit — the repo is not
zuraffa-wired, see `.specify/memory/tdd-profile.md`)
Verdict: **PASS**

## Test-first evidence (git history, branch `spec/gutter-error-widget-builder-81`)

| Commit | What |
|---|---|
| `c5295e1` | spec.md + requirements checklist + feature.json pin |
| `fb4660d` | plan.md |
| `77a451b` | tasks.md |
| (working) | T1 test file written → **red**: `flutter test` fails to compile — `No named parameter with the name 'errorPopupBuilder'` |
| `c18690b` | T2–T4 implementation → **green**: +6 tests |

The test file and the spec/plan/tasks artifacts all predate the first line of
lib/ change; the red reason is the missing API, not a broken assertion.

## Red-phase evidence (cycle-log.md)

Recorded per behavior: red proven (compile failure naming the absent
parameter) before implementation; green run after the smallest possible change
(one field, one relay, one `?:` chain at the call site).

## Test-smell rubric

- **No mock of the system under test.** `TestAnalyzer` doubles the analyzer
  only, exactly as `error_popup_decoration_test.dart` and
  `error_icon_override_test.dart` do — the gutter, style and
  `GutterErrorWidget` under test are all real.
- **Sentinel, not introspection.** The override tests assert a distinct widget
  type is mounted (`SentinelPopup`) and the built-in is absent — observable
  behaviour, not internal state.
- **Characterization first.** The default arm pins the pre-change render
  (glyph, colour, null decoration) so the "default does not change" criterion
  is regression-guarded, not just documented.
- **Every test asserts.** No `expect`-less tests; the builder-arguments test
  captures the triple through closure variables and asserts each.

## Mutation results

Mutants injected into the changed files, run against the feature's test file:

| Mutant | Change | Result |
|---|---|---|
| M1 | default arm of `_fillIssues` returns `SizedBox.shrink()` instead of `GutterErrorWidget` | **killed** — default-render test |
| M2 | `copyWith` relay `errorPopupBuilder ?? this.errorPopupBuilder` → `this.errorPopupBuilder` | **killed** — copyWith replacement test (initially **survived**: the test used the same function reference for old and new builder; strengthened with a distinct second builder `_sentinel2`, then killed — red verified under the mutant, green after restore) |
| M3 | builder arm never consulted (`style.errorPopupBuilder?.call(` → `null ?? null?.call(`) | **killed** — replaces-the-widget and receives-the-triple tests |

3/3 killed.

## Acceptance-criteria coverage

- [x] `GutterStyle` accepts `errorPopupBuilder`, nullable, typed
      `Widget Function(Issue, TextStyle, BoxDecoration?)?` — U1.
- [x] Builder called per issue with the same popup text style and decoration
      the built-in widget gets — A1, per-issue test.
- [x] `GutterErrorWidget` constructed exactly as today when the builder is
      null — A3 characterization.
- [x] A style that sets no builder renders identically — A3.
- [x] `copyWith` carries the new field — U2, M2-killing.
- [x] Public API exported as before — no new file; `gutter_style.dart`
      already exported.
- [x] Coverage stays at the 100% gate — `3430/3430` lines, gate OK, full
      suite 819 green.

## Suite state

`flutter test` — 819 tests, all green. `dart analyze --fatal-infos` — clean.
`dart format --set-exit-if-changed` — clean. Coverage gate: 100.00%.

## Remediation tasks

None — verdict PASS.
