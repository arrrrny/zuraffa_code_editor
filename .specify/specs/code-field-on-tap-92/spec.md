# Verification & implementation: expose a tap callback on the editor (#92)

**Issue:** [arrrrny/zuraffa_code_editor#92](https://github.com/arrrrny/zuraffa_code_editor/issues/92) — synced from upstream `akvelon/flutter-code-editor#236`.
**Label:** `spec` · **Severity:** `low`

## What was asked

> I've tried wrapping the CodeEditor in GestureDetector() but it doesn't seem to
> work and onTap doesn't exist for CodeEditor, I'm wondering what do I need to do
> to fire a callback when the user taps the CodeEditor region?

## Finding

`onTap` does not exist on any widget in this package, and the workaround in the
issue body cannot be made to work.

The reporter names `CodeEditor`. On this fork there is no such widget: the
examples under `example/lib/` each define their own `CodeEditor` that builds a
`CodeField` (see `example/lib/01.minimal/main.dart:17`), and that is what the
reporter was wrapping. So the fix belongs on `CodeField`, the widget the package
actually exports.

Wrapping is a dead end for a structural reason, not a tuning problem. `TextField`
builds its own `TextSelectionGestureDetector` **inside** the field's render box,
and a `GestureDetector` placed around the field declares its recognizers *before*
those children in the arena. A tap is delivered to the innermost recognizers that
accept it, so the field's own tap recognizer wins and the outer detector is never
informed — a silent failure, exactly the worst outcome the issue names. The layout
is the same for every host; no amount of wrapping can reorder the arena.

`TextField` has had an `onTap` parameter for this purpose for years;
`code_field.dart` simply never forwarded it. The field enumerated the parameters
the editor needed rather than the ones it accepted, so a dozen `TextField`
parameters (`contextMenuBuilder` was one, fixed by #12) were reachable only by
patching the package.

## Decision

Forward `onTap` from `CodeField` to the `TextField` it builds
(`lib/src/code_field/code_field.dart:653`). Add no gesture detector of any kind.

- **The gesture is the field's own.** The callback fires from the recognizer that
  already places the caret, so a tap both notifies the host and leaves the caret
  where it was always left. Nothing about placement, selection or focus moves.
- **A `GestureDetector` in the tree would compete**, and a losing recognizer
  inside the field would have to be restructured to hand the arena up. That is a
  much larger change to `TextField`'s internals for the same observable result.
- **No new `enabled` semantics.** The parameter is forwarded as is; a disabled
  field's gestures are already inert.

## Deliverable

| Change | Where |
|---|---|
| `final VoidCallback? onTap` + constructor parameter | `lib/src/code_field/code_field.dart` |
| `onTap: widget.onTap,` on the inner `TextField` | `lib/src/code_field/code_field.dart:653` |
| `test/src/code_field/code_field_on_tap_test.dart` | 5 tests |

The parameter is documented on the widget with the wrapping explanation above,
so the next host that tries a `GestureDetector` reads why it fails before trying.

## Verification

- `flutter test test/src/code_field/` → **381 passed** (376 existing + 5 new).
- `dart analyze --fatal-infos` → no issues.
- `dart format --output=none --set-exit-if-changed .` → clean.
- Full suite + `tool/coverage_gate.py --min 100` → see the PR's CI run.

Fault-injected by deleting `onTap: widget.onTap,` from the `TextField` call:
3 of the 5 tests go red behaviourally (the two callback tests and the caret test,
which counts taps), and the remaining two — the no-callback field and the focus
test — stay green, which is the correct split: only the forwarded parameter can
regress.
