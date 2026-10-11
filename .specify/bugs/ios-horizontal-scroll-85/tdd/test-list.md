# Test list: ios-horizontal-scroll-85

Behaviors derived from `spec.md` acceptance criteria. The project is not
zuraffa-wired (`.zfa.json` absent), so this list was derived by hand per the
LLM-guided fallback in `/speckit-tdd-plan`.

Note on the loop: the first pass of this list was written while the reported
symptom was still taken at face value, and measured the code area **unfocused**.
That produced a false red for the caret reveal (`_scheduleShowCaret` is gated on
focus, so an unfocused field never reveals its caret). The list and the tests were
rewritten against focused measurements; the wrong numbers are kept in
`tdd/cycle-log.md` so the trap is not re-entered.

## Outer loop (acceptance)

| ID | Behavior | Criterion | Test |
|----|----------|-----------|------|
| B1 | A drag over the code text scrolls `_horizontalCodeScroll` under an iOS platform override | AC-1 | `test/src/code_field/horizontal_scroll_behaviour_test.dart` — "the code area scrolls horizontally on drag / under an iOS platform override" |
| B2 | The same drag leaves the position alone under an android platform override (Flutter claims it for text selection) | AC-1 | same file — "an android platform override leaves the drag to text selection" |
| B3 | `End`, `Home` and `→` reveal the caret horizontally on the focused field | AC-2 | same file — "the caret is revealed horizontally / End, Home and the arrow keys move the code area" |
| B4 | Typing a long line ends with the caret revealed | AC-2 | same file — "typing a long line ends with the caret in view" |
| B5 | Content that fits the viewport is not scrolled | AC-3 | same file — "the code area leaves it alone when there is nothing to scroll / content that fits the viewport" |
| B6 | `wrap: true` reflows instead of scrolling | AC-3 | same file — "wrap: true reflows instead of scrolling" |

## Inner loop (unit)

| ID | Behavior | Traces to | Test |
|----|----------|-----------|------|
| U1 | The horizontal scroll view exists only on the unwrapped path | B6 | exercised through B6 (`findsNothing` for the horizontal `Scrollable`) |

## Status

All behaviors GREEN at baseline (2026-10-11, master `89ff2c6`, branch
`bug/ios-horizontal-scroll-85`) — this change ships pins, not a fix. See
`assessment.md` for why.
