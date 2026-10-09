# TDD Test List: scroll-controller-not-attached

Feature: .specify/bugs/scroll-controller-not-attached
Spec: ./spec.md · Engine: raw (`flutter test`) — `zfa` is not wired into this repo

## Outer-loop behaviors (from acceptance criteria)

| ID | Behavior | Traces to | Test file | Status |
|----|----------|-----------|-----------|--------|
| B1 | `scrollOffsetOrZero()` returns 0 for a detached controller instead of asserting | AC1 | `test/src/code_field/popup_offset_detached_scroll_test.dart` | GREEN |
| B2 | `scrollOffsetOrZero()` forwards the offset of an attached controller | AC1 | `test/src/code_field/popup_offset_detached_scroll_test.dart` | GREEN |
| B3 | Analysis notification with detached scroll controllers does not throw | AC2 | `test/src/code_field/popup_offset_detached_scroll_test.dart` | GREEN |
| B4 | Popup offset still computed for a laid-out field | AC3 | `test/src/code_field/popup_offset_detached_scroll_test.dart` | GREEN |

## Guard

| ID | Behavior | Traces to | Test file | Status |
|----|----------|-----------|-----------|--------|
| G1 | Full pre-existing suite stays green | AC4 | `flutter test` | GREEN |

## Red scenarios (must fail before the fix)

- B1/B2: before the fix there is no `scrollOffsetOrZero` — the test cannot
  compile, and the call sites use `controller.offset` directly, which asserts
  `ScrollController not attached to any scroll views` on a detached controller.
  The mutation was run explicitly: removing the `hasClients` guard from the
  helper makes B1 fail with exactly the upstream assertion.
