# Fix: gutter-overflows-narrow-field

- **Status**: applied
- **Branch**: `bug/gutter-overflows-narrow-width-259`
- **Base**: `105d298` (master)

## Change

`lib/src/code_field/code_field.dart` — the gutter is bounded to the width the
row has, through a `LayoutBuilder` around the `Row` and a
`ConstrainedBox(maxWidth: constraints.maxWidth)` on the gutter. The code area
stays the `Expanded` child it already was, so it keeps every pixel the gutter
is not using.

One production change, zero new public API, and no change to any width the
gutter derives: `Container.width`, the fixed issue and folding columns and the
`FlexColumnWidth` number column all follow, because they are computed from a
width that is now bounded rather than one that is not.

## Why bounding and not a flex share

The gutter must stay a **non-flex** child. Two flex children split a row between
them, and a flex allocation is not handed back when a child takes less than it:
a `Flexible` gutter asking 80 px inside a 146 px share leaves its sibling the
other 146 px share, so the code area is 66 px narrower than it should be at a
300 px field. That broke three existing tests — the horizontal scrollbar grew a
thumb on a document that fits, and an editor drag at x = 300 missed the code
area. Bounding leaves the `Expanded` allocation as "everything the gutter does
not want", which is what it always was.

## Files

| File | Change |
|---|---|
| `lib/src/code_field/code_field.dart` | `LayoutBuilder` + `ConstrainedBox(maxWidth:)` around the gutter; comment records why it is bounded and not flexed |
| `test/src/gutter/gutter_overflows_narrow_field_test.dart` | new: 7 widget tests, spec behaviours 1–7 |
| `CHANGELOG.md` | `### Fixed` entry under `## Unreleased` |
| `.specify/bugs/gutter-overflows-narrow-field/` | issue, assessment, spec, TDD test list and cycle log |

## Validation

- `flutter test --concurrency=2` — full suite, see `test.md`
- `dart analyze --fatal-infos` — no issues
- `dart format --output=none --set-exit-if-changed .` — clean
- `python3 tool/coverage_gate.py --min 100` with the CI helper — 100.00%
