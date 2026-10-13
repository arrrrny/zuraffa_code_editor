# Test list — horizontal scrollbar (#91)

1. `a code area that cannot scroll shows no thumb` — content that fits gets no
   bar. Red if `thumbVisibility` is ever hardcoded `true` (the bar would lie about
   reach on a short file) or if a second bar appears somewhere it does not
   belong.
2. `a code area that overflows horizontally has a bar` — the headline request.
   Red if the `Scrollbar` is removed.
3. `the bar is laid out with the viewport, not the content` — the exact failure in
   the issue body: a bar inside the scroll view is laid out at the end of the
   content, so it sits below the visible area. Red when the bar is moved inside
   the `SingleChildScrollView` (the trap mutant kills this one together with five
   others), because its box would then be the content column, not the viewport.
4. `the bar belongs to the field's own scroll view` — the bar and the code area
   drive the same controller, so a drag on the thumb moves the code. Red if the
   bar is bound to any other scroll view, or left with no controller.
5. `the bar is always visible, not only while scrolling` — `thumbVisibility` and
   `interactive` are both on. Red if the thumb is left to fade out after a drag,
   or if `interactive` reverts to the platform default and the thumb stops
   responding on touch.
6. `wrap: true reflows instead of scrolling and has no bar` — soft wrapping
   removes the horizontal extent, and `_wrapInScrollView` returns before it builds
   a scroll view. Red if the wrap path ever gains a scroll view.
7. `the vertical scrollbar is unaffected` — the change is horizontal only. Red if
   anything is added to the vertical axis, or if the horizontal bar appears on a
   short vertical document.
