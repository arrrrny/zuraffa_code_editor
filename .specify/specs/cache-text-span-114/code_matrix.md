# Conformance matrix: cache-text-span

Every functional requirement and success criterion, the artifact that satisfies
it, and the test that proves it. A requirement with no test is not satisfied.

| ID | Requirement | Satisfied by | Proved by |
| --- | --- | --- | --- |
| FR-1 | Same object on unchanged consecutive calls | key + `if` in `buildTextSpan` | T002 |
| FR-2 | A no-op notification still hits | key does not include the selection | T003 |
| FR-3 | Text change invalidates | `_code` identity (R2) | T004 |
| FR-4 | Fold / unfold invalidates | `_code` identity (R2, sites 1214/1221/1242) | T005 |
| FR-5 | Style change invalidates | `style` in the key, `TextStyle ==` | T006 |
| FR-6 | Theme change invalidates | `CodeTheme.of(context)` in the key | T007 |
| FR-7 | Search pattern / navigation / close invalidate | `searchResult` + `searchNavigationState` | T008 |
| FR-8 | Language change invalidates | `_language` in the key | T009 |
| FR-9 | No leaf accumulation across calls | a new `SearchResultHighlightedBuilder` per miss (R5) | T011 |
| FR-10 | Composing path is not cached | composing early-return is above the cache | T010 |
| FR-11 | A hit is structurally what a miss builds | nothing else changed in the build path | T012 |
| FR-12 | `lastTextSpan` assigned on every call | the hit path assigns it too | T013 |
| FR-13 | No-language path cached | the cache is above the language branch | T009 |
| SC-1 | analyze clean | T022 | — |
| SC-2 | format clean | T023 | — |
| SC-3 | Pre-existing tests pass | T021 | — |
| SC-4 | 100% line coverage, exemptions unchanged | T024 | — |
| SC-5 | Mutation audit 0 survivors | T025 | M1–M10 |
| SC-6 | Tests written RED first | T001–T014 | the RED transcript in `tdd/verification.md` |

## Mutation coverage of the key components

Each component must be provably load-bearing: removing it must fail a test. A
component with no failing test is speculative code in the key, and speculation in
a key is what turns a perf change into a stale-render bug (R1).

| Key component | Mutation | Killed by |
| --- | --- | --- |
| `_code` | M4 — drop from key | T004, T005 |
| `style` | M3 — drop from key | T006 |
| `theme` | M2 — key on `_getTheme(context)` | T007 |
| `language` | M7 — drop from key | T009 |
| `searchResult` | M5 — drop from key | T008 |
| `searchNavigationState` | M6 — drop from key | T008 |
| the hit return | M1 — always rebuild | T002, T003 |
| the `lastTextSpan` assignment | M8 — skip on hit | T013 |
| the composing guard | M9 — move below the lookup | T010 |
| the stored key | M10 — store span only | T002 |
