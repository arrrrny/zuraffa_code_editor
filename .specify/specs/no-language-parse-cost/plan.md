# Implementation Plan: pin the cost of the keystroke path when no language is selected

**Branch**: `spec/no-language-parse-cost` | **Date**: 2026-10-11 | **Spec**: `.specify/specs/no-language-parse-cost/spec.md`

**Input**: Feature specification from `.specify/specs/no-language-parse-cost/spec.md`

## Summary

Fork issue #111 (upstream `akvelon/flutter-code-editor#246`) reports that
`highlight.parse()` still runs when no language is set, so an unhighlighted
4800-line document allegedly hangs ~20 s per keystroke, and proposes skipping
the parse when the language is null.

**The premise does not hold on this fork, and this plan is scoped to prove and
pin that rather than to change code.** `CodeController._languageId`
(`lib/src/code_field/code_controller.dart:97`) is `''` until `setLanguage`
runs, and `highlight.parse(text, language: '')` resolves through
`highlight`-0.7.0's `_getLanguage(name) ?? plaintext`
(`~/.pub-cache/hosted/pub.dev/highlight-0.7.0/lib/src/highlight.dart:271`)
where `plaintext = Mode(refs: {}, disableAutodetect: true)` — an empty mode
that performs no token work. Measured on a 4800-line / 297 960-char Java-like
document: the highlight step costs **3.0 ms** (15 ms for 5 runs) with no
language versus **318.2 ms** with `java`, and a single keystroke medians
**43–46 ms** versus **378 ms**. There is no multi-second stall, and skipping
the parse could save at most ~3 ms of a 43 ms keystroke.

The deliverable is therefore a **measurement-pinning test** — the same shape as
`.specify/specs/lazy-loading-long-text/test-list.md` and its guard
`test/src/code_field/edit_latency_test.dart` — which asserts the ratio between
the no-language and with-language paths (durable, machine-independent) rather
than an absolute millisecond budget (flaky under `flutter test`'s unoptimized
JIT). No `lib/` change is planned.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.47.5 (`.github/workflows/dart.yaml`)

**Primary Dependencies**: `flutter`, `highlight` 0.7.0 (pinned in
`pubspec.lock`), `linked_scroll_controller`, `meta`

**Storage**: N/A — in-memory immutable `Code` tree held by `CodeController`

**Testing**: `flutter test` (unoptimized JIT) + `tool/coverage_gate.py` at
`--min 100`, enforced by CI on every PR

**Target Platform**: Flutter (mobile, desktop, web) — the package is published
as `zuraffa_code_editor`

**Project Type**: library (Flutter package with a single top-level export in
`lib/zuraffa_code_editor.dart`)

**Performance Goals**: one keystroke on a 4800-line document completes in the
tens of milliseconds; the no-language path is never slower than the
with-language path

**Constraints**: no new dependency; no public API change; absolute millisecond
budgets are forbidden as test assertions (machine-dependent); the coverage gate
stays at 100%

**Scale/Scope**: documents of a few hundred to a few thousand lines; the only
files touched are under `test/`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the **unfilled Spec-Kit template**
(no ratified principles, version placeholders), so there are no project gates
to evaluate beyond the repository's own enforced rules:

| Enforced rule | Where | This feature |
|---|---|---|
| `dart analyze --fatal-infos` | `dart.yaml:55` | passes — test-only change |
| `dart format --set-exit-if-changed` | `dart.yaml:58` | new test formatted with the repo style |
| 100% line coverage | `dart.yaml:91` | a new test adds no uncovered `lib/` lines; it exercises the existing path |
| PRs reviewed and merged by the pool | operator rule | applies to the eventual PR, if one is opened |

No violations. Nothing to justify.

## Project Structure

### Documentation (this feature)

```text
.specify/specs/no-language-parse-cost/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── checklists/          # /speckit-checklist output
├── tdd/                 # /speckit-tdd-plan + /speckit-tdd-run output
│   ├── test-list.md
│   └── cycle-log.md
├── tasks.md             # Phase 2 output (/speckit-tasks command)
└── spec.md              # /speckit-specify output (written)
```

### Source Code (repository root)

```text
lib/
├── zuraffa_code_editor.dart   # single public export
└── src/
    ├── code_field/
    │   └── code_controller.dart   # _createCode → highlight.parse (line 1013)
    └── ...

test/
├── issues/
└── src/
    ├── common/create_app.dart     # createController / pumpController helpers
    └── code_field/
        └── edit_latency_test.dart # precedent: the linearity pin for #22
```

**Structure Decision**: single Flutter package, no new directories. The
measurement test lands in `test/src/code_field/` next to the existing
latency guard, reusing `test/src/common/create_app.dart` for controller
construction. A no-language controller is built by constructing
`CodeController` without ever calling `setLanguage`, which leaves
`_languageId == ''` — the public zero-configuration path the issue reports.
`createController` itself defaults `language ?? java`, so the new test builds
its own controller rather than changing the shared helper (changing it would
silently re-point every other test that relies on the default).

## Complexity Tracking

Not applicable — the Constitution Check has no violations.
