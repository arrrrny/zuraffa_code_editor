# Bug Assessment: Null check operator crash on caretFullHeight!

- **Slug**: caret-full-height-null-crash
- **Created**: 2026-10-09
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/5
- **Verdict**: invalid (already fixed in current code)
- **Severity**: n/a

## Report (verbatim or summarized)

Users report recurring uncaught `Null check operator used on a null value`
exceptions; the reporter suspected `caretFullHeight!`.

## Symptom

Hard crash during layout/rendering when `TextPainter.getFullHeightForCaret`
returns null.

## Reproduction

Not reproducible on current code — the reported site is already guarded (below).

## Suspected Code Paths

- `lib/src/code_field/code_field.dart:549-555` — `_getCaretHeight()`:
  ```dart
  final double? caretFullHeight = textPainter.getFullHeightForCaret(...);
  return caretFullHeight ?? 0;
  ```
  The crash site from the report (`caretFullHeight!`) is now a null-coalescing
  fallback to 0.

Full `!` audit of the package (all remaining null-assertions and their guards):

| Site | Guarded by | Safe? |
|------|-----------|-------|
| `code_field.dart:260` `_focusNode!.attach` | private field assigned in `initState`, never nulled | yes |
| `code_field.dart:272-273` `currentContext!.size!` | `if (!mounted) return;` + post-frame-after-layout | yes |
| `code_field.dart:330-331` `context.size!` | explicit `context != null` check + post-frame | yes |
| `code_field.dart:354` `_editorKey.currentContext!` | `!= null` check on the same expression | yes |
| `code_field.dart:358` `_codeScroll!.offset` | `_codeScroll != null` branch check | yes |
| `code_field.dart:561,573` scroll `!.offset` | controllers created in `initState`, never nulled | yes |
| `code_field.dart:590,593` `_suggestionsPopup!` | assigned on the line above / null-checked before | yes |
| `code_controller.dart:191-192` `patternMap!` | inside `if (patternMap != null)` block | yes |

## Root Cause Hypothesis

The crash was real on the version the reporter used. This fork's 0.1.x line
(repackaged from upstream 0.3.x) already carries the `?? 0` fallback, and every
remaining null-assertion in the package is guarded. Confidence: high.

## Proposed Remediation

**Preferred**: none — no code change. Close the issue as already-fixed with a
link to `_getCaretHeight`.

**Optional hardening**: add a unit test that `_getCaretHeight`-equivalent logic
falls back to 0 for a null caret height (locks the invariant for the 100%
coverage drive). Fold into the coverage effort rather than a standalone fix.

**Files likely to change**: none (optionally a test under `test/src/code_field/`).

## Risks & Considerations

- If a user still reports this crash on the current version, reopen — the audit
  above found no remaining unguarded `!` in lib/src.

## Open Questions

- None.
