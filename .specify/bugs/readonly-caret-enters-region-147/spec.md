# Spec: readonly-caret-enters-region-147

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/147
(found while implementing #120, which converted the read-only tests from value
writes to real `Enter` key events and exposed the split.)

## Requirement

An edit the read-only gate refuses must leave the document **and the caret**
exactly as they were. The gate already refuses the text; the caret must not
move when the text did not.

## Root cause

`insertStr`, `removeChar` and `removeSelection` each write the text and then
write the caret unconditionally:

```dart
void insertStr(String str) {
  final sel = selection;
  text = text.replaceRange(selection.start, selection.end, str);
  final len = str.length;
  selection = sel.copyWith(baseOffset: sel.start + len, ...);
}
```

The read-only gate lives inside the overridden `set value`
(`_getEditResultNotBreakingReadOnly`) and refuses only the **text** write, so
`text` keeps its old value. The next line then writes the selection anyway, and
a selection-only write is never gated — it does not change the text, so
`_code.getEditResult` reports no changed lines and the gate has nothing to
refuse. The caret therefore advances by `str.length` into the region the user
may not edit.

Measured on `e04c06f`, caret at the first character of a `ro//readonly` line:
`value.text` unchanged, `selection` `4 → 5`. A refused `Enter` at offset 4, 5,
6 and 8 all advanced the caret by exactly one.

## Fix

The three mutators now share one `_replaceRange(start, end, str)` helper that
writes the text, and only writes the caret when the text write actually landed:

```dart
void _replaceRange(int start, int end, String str) {
  final sel = selection;
  final textBefore = text;
  final newText = text.replaceRange(start, end, str);

  text = newText;
  if (text == textBefore) {
    return; // the write was refused; the caret must not move either
  }
  ...
}
```

Refusal is detected by comparing the text before and after, which is the only
signal the value setter gives: it applies the new value or keeps the old one,
with no result code. A refused write leaves `text` untouched, so the caret stays.

## Acceptance

- A refused `insertStr`, `removeChar` and `removeSelection` leave both the text
  and the caret unchanged.
- A refused `Enter` through the real key path (`onEnterKeyAction` →
  `insertStr('\n')`) leaves both unchanged, at every read-only offset.
- An accepted edit still moves the caret exactly as before.
- No regression: full suite green, `dart analyze` clean, `dart format` clean,
  coverage gate at 100%.

## Non-goals

- Making the caret unselectable inside the read-only region: the user may still
  *place* the caret there with the arrow keys, and that is correct — only an
  edit that would change the text is refused.
- Gating `setCursor`, which deliberately lets a caller position the caret
  anywhere (it is how the tests below reach the read-only region at all).
- Fixing the same shape in `insertSelectedWord`, which writes the whole
  `TextEditingValue` in one assignment and is therefore already atomic.
