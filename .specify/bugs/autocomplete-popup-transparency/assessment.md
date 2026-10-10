# Bug Assessment: Autocomplete popup transparency cannot be turned off

- **Slug**: autocomplete-popup-transparency
- **Created**: 2026-10-10
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/34
  (upstream akvelon/flutter-code-editor#273, labeled `[question]`)
- **Verdict**: valid — no user-facing control over the popup background
- **Severity**: low (cosmetic), but a recurring upstream ask
- **Status**: **resolved by PR #54** (merged 2026-10-10) — `_popupBackground = autocompleteBackground ?? _backgroundCol ?? themeData.cardColor`; kept as the source assessment for `fix.md`.

## Symptom

The autocomplete popup is transparent (code shows through it) and there is
no way to turn that off. The reporter's screenshot shows the suggestion
list with the editor's text visible behind it.

## Root Cause

The popup's background is not its own concern in the current design:

- `CodeField._buildSuggestionOverlay` passes `backgroundColor:
  _backgroundCol` to `Popup` (at the fix's base `0d57280`: `:698`; line
  numbers rot, so the symbol is the stable citation).
- `_backgroundCol` is the **editor's** background:
  `widget.background ?? CodeTheme root style background ??
  DefaultStyles.backgroundColor` (grey.shade900).
- The `if (widget.decoration != null)` branch in `CodeField.build` nulls
  `_backgroundCol` (base `0d57280`: `:426`), deliberately so the decoration
  paints the field background. The popup inherits that null, and
  `Popup.build` puts `widget.backgroundColor` straight into the
  `BoxDecoration` (`lib/src/wip/autocomplete/popup.dart:99`), so a null
  there means a fully transparent popup.

Net effect: any user who sets `CodeField.decoration` (a very common way
to theme the field) gets a transparent suggestion popup, and no public
API anywhere — neither `CodeField` nor `CodeThemeData` — lets them
choose a different color. That is the "cannot be turned off" the issue
names. On light themes the default grey.shade900 also looks out of
place, again with no override.

## Proposed Remediation

1. **Opaque fallback when `_backgroundCol` is null**: in
   `_buildSuggestionOverlay`, pass `_backgroundCol ??
   themeData.cardColor` (or `DefaultStyles.backgroundColor`), so the
   popup is never transparent just because a decoration is set. This
   alone fixes the reported symptom.
2. **Explicit knob**: add an optional `autocompleteBackground` (name TBD,
   e.g. `suggestionBackground`) `Color?` on `CodeField`, threaded to the
   popup; null keeps today's behavior. Default behavior change is
   limited to the null case in (1).

## Tests to add

- Widget test: `CodeField(decoration: BoxDecoration(...))` with a
  suggestion popup open → the popup's inner `Container` resolves to an
  opaque color (not null).
- Widget test: explicit `autocompleteBackground: Colors.red` wins over
  both the decoration path and the theme fallback.
- Regression: no decoration → the popup background still equals the
  editor background (today's default).

## Risks & Considerations

- The wip autocomplete path is only partially covered
  (`lib/src/wip/autocomplete/popup.dart` still has uncovered lines on
  the coverage ratchet); adding the knob adds a little surface. Keep
  the change minimal so the gate does not regress.
- The popup is built in an `OverlayEntry` outside the field's subtree,
  so a theme-derived fallback must be captured from the field's context
  (available in build()) — same pattern as `_backgroundCol`.
