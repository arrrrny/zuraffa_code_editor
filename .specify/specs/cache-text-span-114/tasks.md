# Tasks: cache-text-span

Ordered. Every test task is RED before the implementation task that turns it
green. `TDD-verify` at the end.

## Write the tests (RED)

- [ ] **T001** `test/src/code_field/build_text_span_cache_test.dart` — fixture:
  `pumpController` from `test/src/common/create_app.dart` for the themed case, a
  hand-built `MaterialApp > CodeField` for the no-`CodeTheme` case, and a
  `CodeTheme`-wrapped variant. A `_span(context)` helper that calls
  `controller.buildTextSpan(context: ctx, style: const TextStyle())`.
- [ ] **T002** FR-1: two consecutive calls with nothing in between return
  `identical` objects.
- [ ] **T003** FR-2: a `controller.notifyListeners()` that changes nothing the
  span depends on (a selection change) still hits.
- [ ] **T004** FR-3: assigning `controller.text` produces a different object whose
  plain text contains the new character.
- [ ] **T005** FR-4: `controller.foldAt(...)` invalidates; `controller.unfoldAt(...)`
  invalidates again.
- [ ] **T006** FR-5: a second call with a different `style` invalidates.
- [ ] **T007** FR-6: a hit with a `CodeTheme` in scope; a hit with **no**
  `CodeTheme` in scope; a new `CodeThemeData` in scope invalidates.
- [ ] **T008** FR-7: typing a pattern into the search invalidates; navigating to
  the next match invalidates; closing the search invalidates. Assert the
  highlighted match follows `navigationController.value`, so the test is not
  merely "a different object".
- [ ] **T009** FR-13: the no-language path is cached, and invalidates on text
  change.
- [ ] **T010** FR-10: with a composing range set on `controller.value`, two calls
  return **different** objects (the composing branch is not cached), and the
  composing range survives — mirroring
  `test/src/code_field/code_controller_ime_composition_test.dart:234`.
- [ ] **T011** FR-9: with an active search, the second call's leaf count equals
  the first's — the builder is reconstructed per miss, not reused.
- [ ] **T012** FR-11: a hit's plain text, leaf count and per-leaf styles equal a
  freshly built miss's. Build the "expected" tree from a second controller over
  the same text so the comparison is against a real construction rather than a
  literal.
- [ ] **T013** FR-12: `lastTextSpan` is the returned object on both paths.
- [ ] **T014** Run: `flutter test test/src/code_field/build_text_span_cache_test.dart
    --concurrency=2`. **All of T002–T013 must fail.** Any that passes before the
  implementation is a vacuous test — find the reason and fix the test, not the
  expectation. (T003 and T012 are the two most likely to pass by accident.)

## Implement

- [ ] **T015** Add the private `_SpanCacheKey` record alias (`plan.md`) and the
  two private fields to `CodeController`.
- [ ] **T016** Add the key construction and the hit return to `buildTextSpan`,
  after the composing early-return and before `_createTextSpan` is reached.
- [ ] **T017** On a miss, store key and span, assign `lastTextSpan`, return.
- [ ] **T018** Remove the `TODO(alexeyinkin)` comment at the `buildTextSpan` site
  — it is now done.
- [ ] **T019** Correct the `lastTextSpan` doc comment: a hit means the text was
  *not* re-requested.
- [ ] **T020** Run: `flutter test test/src/code_field/build_text_span_cache_test.dart
    --concurrency=2` → all green.

## Regression net

- [ ] **T021** `flutter test --concurrency=2` → the whole suite green. The
  existing suite has no assertion on instance identity, so this is where a broken
  key would show up as a rendering difference in a widget test.
- [ ] **T022** `dart analyze --fatal-infos lib test` → no issues.
- [ ] **T023** `dart format --output=none --set-exit-if-changed .` → 0 changed.

## Gate

- [ ] **T024** `bash /tmp/gate.sh /Users/arrrrny/Developer/zuraffa_114
  /tmp/gate114.log` → `--min 100`, `EXEMPT_LINES` unchanged in count. If
  `span_builder.dart`'s exemption drifts, renumber it *and* say so in the commit
  message; do not add a new exemption for code the test file can reach.
- [ ] **T025** Mutation audit over the cache logic, script committed at
  `.specify/specs/cache-text-span-114/tdd/mutation_audit.py`. Minimum set:

  | # | Mutation | Must be killed by |
  | --- | --- | --- |
  | M1 | drop the `if` hit return (always rebuild) | T002 / T003 |
  | M2 | key on `_getTheme(context)` instead of `CodeTheme.of(context)` | T007 |
  | M3 | drop `style` from the key | T006 |
  | M4 | drop `_code` from the key | T004 |
  | M5 | drop `searchResult` from the key | T008 |
  | M6 | drop `searchNavigationState` from the key | T008 |
  | M7 | drop `language` from the key | T009 |
  | M8 | return the cached span without assigning `lastTextSpan` | T013 |
  | M9 | move the composing check *below* the cache lookup | T010 |
  | M10 | store the span but not the key (compare against `null`) | T002 |

  Restore every original byte-identical, and record the verdicts.

- [ ] **T026** Fill `.specify/specs/cache-text-span-114/tdd/verification.md` with
  the real RED transcript, the final gate numbers and the mutation table.

## Ship

- [ ] **T027** `CHANGELOG.md` — `## Unreleased` entry.
- [ ] **T028** Commit, push `spec/cache-text-span-114`, open the PR against
  `master`. **Do not merge.**
- [ ] **T029** Wait for the pool review + merge task. Rebase the next branch only
  after the merge lands.
