# Test list — Tab accepts the suggestion (#36)

1. `Tab accepts and hides the popup` — the headline request.
   RED without the `popupController.shouldShow` branch in `onTabKeyAction`:
   the text keeps the typed prefix and the popup stays open.
2. `the suggestion the arrows moved to, not the first one` — `selectedIndex`
   is honoured. Same fault reddens it.
3. `Enter still commits as well` — guards the shared preference in
   `onEnterKeyAction` against drift.
4. `Tab inserts the editor indent` — the fallback path. Red if the indent is
   ever removed, which is the regression in the other direction.
5. `an empty suggestion list is not an acceptance` — `PopupController.show`
   early-returns while `enabled` is false, so "showing" is not just "show was
   called".
