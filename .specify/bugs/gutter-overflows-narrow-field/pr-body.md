Fixes the layout half of upstream `akvelon/flutter-code-editor#259` — "Line Numbers escape the widget".

Closes #158

## The ask

A `CodeField` narrower than its gutter renders a gutter wider than the field: the numbers paint outside the widget, and the code area is laid out out of sight with them. The reporter's own workaround — wrapping the field in a scroll view — works because the row then has an unbounded width to give.

The scroll half of this report was closed here verification-only (fork issue #19, PR #58): the gutter's and the editor's controllers already come off one `LinkedScrollControllerGroup`, and that is pinned. This PR is the half that was left open.

## Reproduction

Measured on master at a 60 px field:

```
FIELD     Rect.fromLTRB(370.0, 0.0, 430.0, 600.0)
GUTTER    Rect.fromLTRB(378.0, 0.0, 458.0, 128.0)   ← 28 px past the field
TEXTFIELD Rect.fromLTRB(458.0, 0.0, 100458.0, 600.0)
A RenderFlex overflowed by 28 pixels on the right.
  creator: Row ← Padding ← ColoredBox ← Container-[GlobalKey] ← Semantics …
```

The gutter escapes the widget, and the `TextField` is laid out at 100 000 px inside a zero-width viewport, so the code is unreachable rather than merely squeezed.

## Root cause

`CodeField.build` puts the gutter and the editor in a `Row` (`lib/src/code_field/code_field.dart:948`). A `Row` lays out its **non-flex** children at their own requested size and gives the flex children what is left, so the gutter — a plain child — was laid out at its full `GutterStyle.width` (80 px by default) whatever the field had. `GutterWidget` honours that width literally, computing it from `style.width` alone (`gutter.dart:106-113`). When the row has less than the gutter wants, the gutter keeps its width, the `Expanded` code area gets a negative remainder, and the row overflows.

Nothing in that geometry could yield, because nothing was asked to: the gutter's width derivation never looks at the field.

## Fix

One production change: the gutter is **bounded** to the width the row has, via a `LayoutBuilder` around the `Row` and a `ConstrainedBox(maxWidth:)` on the gutter. It takes `style.width` when the row can give it and the row's whole width when it cannot. The code area stays the `Expanded` child it already was, so it keeps every pixel the gutter is not using.

No derived width changed — every one of them follows, because it is computed from a width that is now bounded.

## Why bounding and not a flex share — the round trip that matters

The first version of this fix made the gutter `Flexible(flex: 1, fit: FlexFit.loose)`. It passed all six new tests, and reddened three *existing* ones: `horizontal_scrollbar_placement_test`, `line_numbers_follow_scroll_test` and `current_line_highlight_test`.

**A flex allocation is not handed back when a child takes less than it.** The gutter asking 80 px inside a 146 px share does not free those 66 px for its sibling — the `Expanded` code area gets its own separate 146 px share. At a 300 px field the code area was 146 px instead of the 212 px it should be:

- narrow enough that `int a = 1;` overflowed horizontally, so the horizontal scrollbar grew a thumb on a document that fits;
- narrow enough that a drag at x = 300 missed the code area entirely, which is why the gutter-follows-editor drag test never scrolled.

So `Flexible` narrows the code area at *every* field width, including the ones that already worked. The regression suite caught it, and a seventh test now pins the invariant that makes bounding the right instrument rather than a share: `codeArea.width == field.width - 8 - gutter.width`.

## Acceptance criteria

| # | criterion | status |
|---|---|---|
| 1 | the gutter renders inside the field at every width | sweep of 44/60/80/100/120/150/170/200/320 px, both axes, with a framework-error check |
| 2 | every line number renders inside the field | asserted per-number at 60 px |
| 3 | no width in the range raises a framework error | the sweep asserts `takeException()` is null |
| 4 | the code area keeps every pixel the gutter is not using | `codeArea.width == field.width - 8 - gutter.width` at 300 px |
| 5 | a field that can hold the gutter keeps it at `GutterStyle.width` | 400 px field → gutter exactly 80 px |
| 6 | an oversized `GutterStyle(width:)` is capped, not overflowed | `width: 200` in a 60 px field → capped and non-zero |
| 7 | an unbounded field (inside a scroll view) is unchanged | gutter at its full `GutterStyle.width` |

## Tests

7 widget tests in `test/src/gutter/gutter_overflows_narrow_field_test.dart`. Three of them are regression guards that are **green on master** and must stay green — they are what stops the sweep from being satisfiable by a fix that narrows the gutter, or the code area, everywhere.

**Red verified by stashing the fix**: 4 of 7 fail on master with `A RenderFlex overflowed by 28 / 44 / 148 pixels`.

## Out of scope

`GutterStyle.width`'s 80 px default, and the reporter's aside that the sidebar is "so wide". That is a documented, configurable field and a matter of taste — it is not what escapes the widget.

## Validation

- `flutter test --concurrency=2` — full suite
- `dart analyze --fatal-infos` — no issues
- `dart format --output=none --set-exit-if-changed .` — clean
- `python3 tool/coverage_gate.py --min 100` with the CI helper — 100.00%

Spec artifacts: `.specify/bugs/gutter-overflows-narrow-field/`.
