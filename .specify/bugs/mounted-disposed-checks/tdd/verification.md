# TDD Verification: mounted-disposed-checks

- **Feature**: .specify/bugs/mounted-disposed-checks
- **Audited**: 2026-10-09
- **Artifacts audited**: assessment.md · spec.md · tdd/test-list.md · tdd/cycle-log.md · fix.md
- **Engine**: raw (`flutter test`) — `zfa` is not wired into this repo (no `.zfa.json`),
  so this audit is LLM-guided against the same evidence rules.

## Evidence table

| Requirement | Evidence | Verdict |
|---|---|---|
| Test-first | `test-list.md` derives B1/B2/B3/G1 from AC1–AC4 before any guard existed; both test files were written before the source guards (`cycle-log.md`, 2026-10-09 RED entry) | PASS |
| Red-phase evidence | B1 RED proven twice: first run on unpatched source, then re-proven by stashing `lib/src/gutter/error.dart` — `setState() called after dispose(): _GutterErrorWidgetState` | PASS |
| Red-phase evidence | B2 RED — but only on the test-harness invariant (`A Timer is still pending even after the widget tree was disposed.`), never on a source defect; the reported crash does not reproduce on Flutter 3.47.5 | PARTIAL |
| Green-phase evidence | `flutter test` → 299/299 green (295 pre-existing + 4 new) | PASS |
| Acceptance coverage | AC1→B1, AC2→B2, AC3→B3 (happy path in both files), AC4→G1; every AC has at least one executed test | PASS |
| Mutation results | B1: removing the `if (!mounted) return;` guard makes the dispose case RED again → the test genuinely kills the mutant | PASS |
| Mutation results | B2: removing the `_disposed` guard from `_onEnterKeyPressed()` leaves both tests GREEN (deterministic mutation run, 2026-10-09) — `FocusNode.requestFocus` on a detached node is a silent no-op on Flutter 3.47.5, so no current test can detect the guard's absence | GAP |
| Test smells | No sleeps, no logic in test bodies beyond setup/assertions, both tests use the real widget tree, dispose cases + happy paths both covered | PASS |
| Scope discipline | No source changes outside the two sites named by the assessment | PASS |

## Verdict: PASS_WITH_GAPS

The lifecycle hardening is correctly tested where the defect was reproducible
(B1 kills its mutant). The remaining gap is a **toolchain gap, not a test-authoring
lapse**: on Flutter 3.47.5 the second symptom cannot be expressed as a failing test
because the buggy call is already a no-op. The `_disposed` guard is real hardening
for toolchains where it is not (and for future Flutter focus-internal changes).

## Follow-ups

- Re-run the B2 dispose case against the minimum Flutter the package supports once
  that floor is settled by #7; if any supported Flutter throws on a focus request to
  a detached node, the test will catch it there.
- Optional: assert `controller.searchController.patternFocusNode` is not requested
  after dispose by spying with a `ValueNotifier`-free focus listener count, which
  would make the mutation detectable without depending on Flutter internals.
