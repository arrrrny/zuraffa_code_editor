# Test list — RTL / Arabic text direction support (#14)

1. `an explicit textDirection reaches the field` — `CodeField(textDirection: rtl)`
   puts `TextDirection.rtl` on the `TextField` it builds. RED if the parameter
   stops being forwarded.
2. `an LTR locale leaves the field LTR` — the default resolves the ambient
   direction, which is LTR here. RED if the field hardcodes RTL or starts
   defaulting to something else.
3. `an ambient RTL locale is detected without a parameter` — a
   `Directionality(rtl)` inside `home:` reaches the field with no parameter set.
   RED if the field ever stops reading the ambient direction (e.g. by hardening
   the parameter to non-null).
4. `an ambient RTL locale measures the caret as RTL` — the caret at
   end-of-text lands within 40px of the editor's left edge under an RTL locale,
   and beyond 250px under an LTR one. RED if the caret painter goes back to
   `TextDirection.ltr`, and with it the popup placement.
5. `an RTL field measures the caret against the RTL layout` — the forced case:
   offset 0 is inside the line rather than at its left edge, and end-of-text is
   the left edge. Same fault.
6. `LTR behaviour is unchanged` — the caret profile is still monotonic and
   still starts to the right of the gutter. RED if the change alters LTR layout.
7. `an RTL locale moves the gutter to the right edge` — the gutter follows the
   text. RED if the gutter is ever pinned to one side.
8. `forcing RTL on the field alone keeps the gutter on the left` — pins that the
   parameter is scoped to the text and does not restructure the layout, which is
   the boundary of this change.
