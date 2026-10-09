# TDD Cycle Log: scroll-controller-not-attached

## 2026-10-09 — cycle

- Feature: .specify/bugs/scroll-controller-not-attached (spec: ./spec.md)
- Stack: raw flutter (`flutter test`) — zfa not wired into this repo.
- Branch: `fix/scroll-controller-not-attached` from master a7c52bf.
- Entry condition: 299 tests green on the branch base.

### RED

- Wrote the two widget cases first (detached controllers / laid-out field). Both
  passed immediately — the crash is not reproducible on Flutter 3.47.5 because
  the test binding builds and lays out in the same synchronous frame.
- Two reproduction attempts, both green (documented in assessment.md →
  "Reproducibility"): `Offstage` child (RenderOffstage still lays out its child)
  and the reporter's `SingleChildScrollView` parent.
- Added the mutation-detectable seam: `scrollOffsetOrZero(ScrollController)`
  helper. B1/B2 are RED by construction — the helper does not exist and the call
  sites use `controller.offset` directly.

### GREEN

- Added `scrollOffsetOrZero()` in `lib/src/code_field/code_field.dart` (returns
  `0` when `!hasClients`) and routed both popup-offset reads through it
  (`:558` and `:578`).
- Test file: `test/src/code_field/popup_offset_detached_scroll_test.dart`
  (4 tests) — all green.
- Mutation check: deleting the `hasClients` guard makes B1 fail with
  `'package:flutter/src/widgets/scroll_controller.dart': Failed assertion: line
  171 pos 12: '_positions.isNotEmpty': ScrollController not attached to any
  scroll views.` — exactly the upstream assertion.
- G1: `flutter test` → 299 tests green (295 pre-existing on master + 4 new).
- `dart analyze --fatal-infos` → 24 info-level issues, the pre-existing master
  set (removed the `meta` import the analyzer flagged as redundant).
