# Bug Assessment: IME composition duplicates/drops characters

- **Slug**: ime-composition-duplicates-characters
- **Issue**: 11
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/11
- **Assessed**: 2026-10-09
- **Verdict**: valid — reproduced at the controller level; upstream has an open
  fix PR (akvelon/flutter-code-editor#319) with the same four root causes

## Reproduction summary

Upstream `akvelon/flutter-code-editor#309` (video only, no comments) and the
same-family `#126` "[Windows10 Desktop] IME doesn't work well" (reproduced by
the reporter with the Basic Usage example: type "test" in English mode, switch
the IME to Chinese, type "Ver"). On Windows one typed character appears twice;
on web two typed characters show one.

## Root cause

`CodeController` treats every platform `TextEditingValue` as a diff of the
previous one. An IME does not produce such diffs: it first inserts the typed
keystrokes as a *composing* region, then *replaces* that region with the
selected candidate. Four defects follow:

1. **Composing-only updates are dropped.** `set value` returns early when only
   `composing` changed (`!hasTextChanged && !hasSelectionChanged`). The
   controller's value then desynchronizes from the engine's IME state, which on
   Windows manifests as duplicated characters on commit.
2. **A composition commit is misclassified as backspace and the candidate text
   is deleted.** Reproduced: `'} ni'` with `composing (2,4)` committed as
   `'} 你'` produced `'} n'`. `getChangedRange` classifies the shrink as
   `backspaceBeforeCollapsedSelection`, which returns a *collapsed* range, so
   the caller's replace region inserts nothing and deletes the composing chars.
3. **Transforms fire on composing text.** The paired-symbol modifier turned
   `a(` into `a()` while `composing (1,2)` was active.
4. **Transient out-of-range selections throw.** A composition shrink with a
   stale platform selection (`' } n'` with selection at offset 5) threw
   `RangeError` from `tabsToSpaces` → `beforeSelection`.

## Current state on this fork

- `lib/src/code_field/code_controller.dart` — none of the four fixes present;
  `composing` is only referenced by `text_editing_value.dart` copy-throughs.
- `lib/src/code/code.dart:318 getEditResult` — no clamping of selections
  reported by the platform.

## Proposed fix

Port upstream PR #319 (adapted, without its debug `print` and cosmetic
`String` → `var` churn):

- `CodeController.hasActiveComposition` getter.
- `set value`: apply composing-only updates; while a composition is active in
  either the old or the new value, store the platform value verbatim (after
  syncing the internal `Code`) with no diff-based transforms.
- `onKey` / `onEnterKeyAction` / `onTabKeyAction` and the Enter/Tab/Escape
  shortcuts in `code_field.dart`: ignored while composing.
- `buildTextSpan`: delegate to the default composing-aware implementation while
  composing.
- `Code.getEditResult`: clamp old/new selections into the text range before
  diffing.

## Verification plan

- RED tests for each defect (see tdd/test-list.md), then the fix, then GREEN.
- Mutation checks for the controller guards, the `set value` composing path,
  and the selection clamping.
- Full suite must stay green (313 → 314 tests).

## Severity / effort

- Severity: high — Chinese/Japanese/Korean input is the primary use case for
  this class of editor and the bug makes composition unusable (dropped or
  duplicated characters).
- Effort: medium — one controller, one diff helper, one widget map; no API
  change.
