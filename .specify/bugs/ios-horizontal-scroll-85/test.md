# Test report: ios-horizontal-scroll-85

- **Slug**: ios-horizontal-scroll-85
- **Date**: 2026-10-11
- **Branch**: `bug/ios-horizontal-scroll-85` @ `89ff2c6`
- **Baseline**: master `89ff2c6` (no `lib/` change — this change is pins only)

## Scope

New file `test/src/code_field/horizontal_scroll_behaviour_test.dart` (6 tests,
4 groups) pinning the measured horizontal-scroll behaviour of the code area.

## Results

```
$ flutter test test/src/code_field/horizontal_scroll_behaviour_test.dart
00:09 +6: All tests passed!
```

| Test | Result | What it pins |
|------|--------|--------------|
| the code area scrolls horizontally on drag / under an iOS platform override | GREEN | 0 → >0 on a 240 px leftward drag |
| ... / an android platform override leaves the drag to text selection | GREEN | stays 0, with the Flutter reason in the test body |
| the caret is revealed horizontally / End, Home and the arrow keys move the code area | GREEN | caret at end revealed, `Home` → ~0, `End` → revealed, 30x `→` past the edge → revealed |
| ... / typing a long line ends with the caret in view | GREEN | `enterText` of 300 chars ends revealed |
| ... / content that fits the viewport | GREEN | `maxScrollExtent == 0`, `pixels == 0` |
| ... / wrap: true reflows instead of scrolling | GREEN | no horizontal `Scrollable` at all |

## The measurements behind the pins

Example-02 widget tree, `_horizontalCodeScroll.position.pixels`, 240 px leftward
drag over the code text:

```
defaultTargetPlatform=iOS     before=0.0  after=201.16666666666669
defaultTargetPlatform=android before=0.0  after=0.0
```

Mechanism attribution (recognizer vs scroll physics):

```
default=iOS      theme=android  after=201.16666666666669
default=android  theme=iOS      after=0.0
```

Caret reveal, focused field, `maxScrollExtent == 446`:

```
setup          px=4740.0   caret at offset 300 (end of a 300-char line)
after End      px=4740.0   caret at offset 300
after Home     px=0.333    caret at offset 0
after 30xRight px=285.33   caret at offset 30, past the right edge -> revealed
after tap      px=285.33   caret placed by a tap -> revealed
```

## Gates

| Gate | Command | Result |
|------|---------|--------|
| Full suite | `flutter test` | 737 passed (the 6 new pins on an unmodified `lib/`) |
| Analyze | `dart analyze lib/src/code_field/code_field.dart test/src/code_field/horizontal_scroll_behaviour_test.dart` | No issues found |
| Format | `dart format` | Formatted 2 files, 0 changed after the run |
| Coverage | `tool/coverage_gate.py --min 100` | 100.00% (3360/3360 lines over 105 files) — test-only change, no new production lines |

## Not covered, and why

- A real iOS device or simulator run. The platform split is reproduced with
  `debugDefaultTargetPlatformOverride`, which selects the same recognizer and the
  same scroll physics a real build does; a device run would confirm the report
  author's setup but cannot change the arena outcome.
- The `Scrollbar` follow-up, which does not exist yet.

## A trap worth recording

The caret reveal must be measured with the field **focused** —
`_scheduleShowCaret` is gated on focus, so an unfocused field never reveals its
caret and the measurement reads as a false red. The first three probes of this
issue made exactly that mistake.
