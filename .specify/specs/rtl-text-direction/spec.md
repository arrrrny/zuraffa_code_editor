# RTL / Arabic text direction support (#14)

**Issue:** [arrrrny/zuraffa_code_editor#14](https://github.com/arrrrny/zuraffa_code_editor/issues/14) — synced from upstream `akvelon/flutter-code-editor#317`.
**Label:** `spec`

## What the issue asks for

> * The editor should detect or allow setting the `textDirection` to `TextDirection.rtl`.
> * Proper cursor placement and movement logic for RTL text.
> * Support for Arabic characters without overlapping or rendering issues in the code lines.
> * Ensures the gutter (line numbers) stays correctly positioned relative to the RTL text.

## What already worked

**Detection.** `CodeField` builds a `TextField` (`lib/src/code_field/code_field.dart`) with no `textDirection`, and `EditableText` resolves a null one from `Directionality.of(context)`. An app whose locale is Arabic installs RTL for the whole subtree, so the text and the caret — including the platform's own arrow-key movement, which is Flutter's, not the editor's — already behave correctly with no configuration. Probe: with a `Directionality(textDirection: rtl)` inside `home:`, the field lays out RTL, the gutter flips to the right edge (the `Row` it sits in reads the ambient direction), and Arabic glyphs render through the same `TextField` the Latin case uses. The BiDi reordering the issue calls out is the platform's bidi algorithm, which applies once the paragraph direction is right; it is not something the editor implements.

## What was missing

**Allowing it.** Nothing let a caller *force* the direction — a right-to-left snippet inside a left-to-right app had no way to say so. And more importantly, **the direction the field rendered in was invisible to everything the editor measured with.** Every `TextPainter` the field builds hardcoded `TextDirection.ltr`:

| Painter | Used for | Direction-dependent? |
|---|---|---|
| `_getTextPainter` | the caret offset that positions the autocomplete popup (`_getPopupLeftOffset`) | **yes — horizontally** |
| `_measureWrappedRows` | the height of each wrapped row | no |
| `_singleLineHeight` | the floor a row may not collapse below | no |
| `gutter._widestNumberWidth` | the width of the widest line number | no |

So in an RTL field the popup was placed where the caret *would* be if the text ran left to right — the far side of the editor. That is the reported defect, and it is the one this change fixes.

## What this change does

1. `CodeField.textDirection` (`TextDirection?`, default null). Left null the field resolves the ambient `Directionality`, so detection keeps working and nothing changes for existing callers; set it to force a direction.
2. The resolved direction is written into the `TextField` and into `_getTextPainter`, so the caret measurement — and therefore the popup that hangs off the caret — is taken against the layout the field actually renders.
3. The row-height painters stay `TextDirection.ltr`, deliberately and documented: a paragraph's direction moves text horizontally, never vertically. Threading it there would add churn without changing a measurement.

Explicitly out of scope: the gutter flip (already handled by the ambient direction), and the BiDi algorithm itself (the platform's).

## Deliverable

`test/src/code_field/text_direction_test.dart` — 8 tests:

| Test | Pins |
|---|---|
| an explicit textDirection reaches the field | the "allow setting" half |
| an LTR locale leaves the field LTR | the default |
| an ambient RTL locale is detected without a parameter | the "detect" half |
| an ambient RTL locale measures the caret as RTL | end-of-text lands at the left edge; LTR puts it at the right |
| an RTL field measures the caret against the RTL layout | the forced case, and the mirror |
| LTR behaviour is unchanged | the monotonic caret profile, offsets within the gutter gap |
| an RTL locale moves the gutter to the right edge | the gutter stays with the text |
| forcing RTL on the field alone keeps the gutter on the left | the parameter is about the text, not the app |

Fault-injected by reverting `_getTextPainter` to `TextDirection.ltr`: the two caret-direction tests go red, the gutter tests stay green.
