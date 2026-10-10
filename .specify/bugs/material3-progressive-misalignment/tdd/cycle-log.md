# TDD cycle log — #28 Material 3 gutter/code misalignment

## Red — write a test that reproduces

1. Read the report: Material 3 only, drift grows per line. That points at a
   theme-derived metric, and `CodeField` reads exactly one theme entry for its
   code style — `themeData.textTheme.titleMedium`, from which it takes both
   `fontSize` and `height`.
2. First attempt: mirror `gutter_alignment_test.dart` but wrap in
   `MaterialApp(theme: ThemeData(useMaterial3: true))`. **This test is
   insensitive** — it also passes with the fix removed, because it passes an
   explicit `textStyle: TextStyle(height: 1.6)`, and `copyWith(height: null)`
   preserves the receiver's `height`.
3. Probed the real numbers with a scratch test:
   editor rendered line height `24.0`, gutter row pitch `24.0` with a default
   gutter style — no drift to detect.

## Green — find the state that actually breaks

The gutter style resolves as `(widget.gutterStyle.textStyle ?? textStyle)`.
Passing a `gutterStyle.textStyle` of the caller's own (no `height`) reaches the
state the fix protects. Measured with the `height:` copy removed:

```
editor rendered line height = 24.0
gutter row pitch            = 23.0   → 1 px per row, unbounded growth
```

That is the reported "progressive misalignment", reproduced.

## Refactor — pin both states

Final test file asserts the invariant three ways: unfolded under Material 3,
folded under Material 3, and with a caller-supplied height-less gutter style.
The third is the fault-detecting one; the first two are the guards the issue's
specific reproduction always lacked.

Guard added so the test cannot silently stop testing Material 3: assert
`editable.style.height` is non-null, i.e. that `titleMedium` really is the
source of the line height.

## Verification

```
flutter test                                  → 564 tests, all passed
flutter test test/src/gutter/gutter_alignment_material3_test.dart
                                              → 3 tests, all passed
dart format --output=none --set-exit-if-changed .   → no changes
dart analyze --fatal-infos lib test tool      → No issues found!
```

No source change. The 100 % line-coverage gate is unaffected: the file adds
tests only, no new `lib/` lines.
