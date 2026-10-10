# #19 — cycle log

## Red

Not applicable in the source-changing sense: the reported symptom did not
reproduce, so there was no failing test to write first. The tests were written
as a characterisation of the current — correct — behaviour instead.

## Green

All three tests pass on the first run.

- `flutter test test/src/code_field/line_numbers_follow_scroll_test.dart` — 3 passed

## What was ruled out

- `_numberScroll` unused — it is wired to `GutterWidget`
  (`code_field.dart:637`), from the same `LinkedScrollControllerGroup` as
  `_codeScroll` (`code_field.dart:290-292`).
- The wrap path as the place the two views disagree — covered by test 3.
- The gutter escaping past its own content — explicitly asserted against
  `gutter.maxScrollExtent` in test 1.

## Conclusion

Upstream's root cause does not exist on this fork. No source change; the tests
land as a regression guard.
