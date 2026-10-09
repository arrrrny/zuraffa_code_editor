# TDD Cycle Log: RenderBox was not laid out when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Issue**: 32

## RED

`test/src/code_field/code_field_notify_before_layout_test.dart` written before the
fix. The repro is a `_NotifyOnLayout` sibling ahead of the `CodeField` in a
`Column`: its `performLayout()` calls `controller.notifyListeners()`, i.e. the
editor box is mounted but `flushLayout` is still running.

First run failed on master:

```
RenderBox was not laid out: RenderFractionalTranslation#… NEEDS-LAYOUT
NEEDS-PAINT … Failed assertion: line 2165 pos 12: 'hasSize'
```

(reached from `_CodeFieldState._onTextChanged` → `box.localToGlobal(Offset.zero)`,
which is the frame upstream #275 reported).

Two earlier attempts were rejected before settling on this shape:

- the same notification inside the `CodeField`'s own build/layout asserted
  `Build scheduled during frame` from `GutterWidget`'s `AnimatedBuilder` and
  only Material/overflow noise from the harness — the field is now pumped
  inside `Scaffold` + `Expanded` and with `GutterStyle.none`;
- `SchedulerBinding.instance.schedulerPhase == SchedulerPhase.transientCallbacks`
  as the guard does not identify the window (the phase is `idle` during the
  initial frame's layout), so `hasSize` on the editor box is used instead.

## GREEN

`_isEditorBoxLaidOut` guard added, wired
into `_onTextChanged` and `_updatePopupOffset`. Both tests pass;
`git stash` of the lib change restores RED.

## Mutation checks

- Reverting `lib/src/code_field/code_field.dart` to `origin/master` (the exact
  change under test) reproduces the `hasSize` assertion — the tests are not
  vacuous.
- The guard is false only while the box is unlaid-out, so the second test is the
  proof that a follow-up notification once the box is laid out is processed
  cleanly. The skipped mid-frame work itself is not rescheduled.

## Full suite

352 tests pass with the fix in place (350 on master + 2 new).
