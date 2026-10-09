# Spec: Guarded popup-offset scroll reads (bug scroll-controller-not-attached)

Source assessment: ./assessment.md (issue #10, upstream akvelon/flutter-code-editor#275)

## Problem

The autocomplete popup's offset is recomputed on every controller notification,
and the two scroll offsets it needs are read with a bare `.offset`. When either
controller has no attached scroll view, `ScrollController.offset` asserts
`ScrollController not attached to any scroll views`, so `analyzeCode()`'s
notification prints an exception. The reporter hit it with the field wrapped in
an outer `SingleChildScrollView`.

## Acceptance criteria

- AC1: `scrollOffsetOrZero()` returns the live offset when the controller is
  attached, and `0` — never an exception — when it is not.
- AC2: The popup-offset computation uses the guarded read for both the code
  field's scroll view and the horizontal wrapper.
- AC3: With a laid-out field, popup offsets are unchanged (happy path pinned).
- AC4: The whole pre-existing suite stays green.

## Failing-test scenarios (red)

1. Unit: `scrollOffsetOrZero(ScrollController())` must not throw
   `ScrollController not attached to any scroll views` — with the unguarded
   read this is a hard failure (the helper does not even exist yet).
2. Widget: analysis notification with a field whose scroll controllers are
   detached does not throw (integration pin; green on current toolchains).

## Out of scope

- Attaching the popup to a detached controller beyond "do not throw".
- Any change to the offset math itself.
