# Spec: codeline-copywith-drops-indent

## Goal

`CodeLine.copyWith` must behave like a Dart `copyWith`: change exactly the fields
the caller passes, leave the rest alone. `indent` must be preserved when `text`
is not replaced, and recalculated when it is.

## Requirements

1. `codeLine.copyWith(isReadOnly: true)` returns a `CodeLine` with the same
   `indent` as `codeLine`.
2. `codeLine.copyWith(textRange: ...)` returns a `CodeLine` with the same
   `indent` as `codeLine`.
3. `codeLine.copyWith(text: X)` returns a `CodeLine` whose `indent` equals
   `_calculateIndent(X)` — i.e. the new text wins, even when the new indent is 0.
4. All other fields (`text`, `textRange`, `isReadOnly`) keep their existing
   "only override what was passed" semantics.
5. A `Code` built with `readOnlySectionNames: {...}` must yield lines inside that
   section whose `indent` matches the source indentation (the regression the bug
   actually caused through `code.dart:181` / `code.dart:200`).
6. Lines outside the read-only section must be unaffected (control test).

## Non-goals

- No change to `operator ==` / `hashCode` / `toString` (they omit `indent`; that
  is a separate pre-existing inconsistency, deliberately out of scope).
- No new public API — `copyWith`'s signature stays `text`/`textRange`/`isReadOnly`.

## Test plan

`test/src/code/code_line_copy_with_indent_test.dart`

- `CodeLine.copyWith` group: override-only (range kept as-is), recalculate on
  text change, preserve when text not passed, `isReadOnly` override.
- `Read-only sections keep their indentation` group: named-section lines keep
  their indent; unmarked code keeps its indent (control).

## Definition of done

- Both RED→GREEN: the preserve tests fail on master (`Actual: <0>`) and pass with
  the fix.
- Full suite green, `dart analyze` clean, `dart format` clean.
- Artifacts in `.specify/bugs/codeline-copywith-drops-indent/` and `tdd/`.
