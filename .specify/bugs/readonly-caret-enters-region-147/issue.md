`Enter` at a read-only position inserts no text but still moves the caret one
character into the read-only region.

## What is wrong

`CodeController.onEnterKeyAction` calls `insertStr('\n')`, and `insertStr`
(`lib/src/code_field/code_controller.dart:515`) is:

```dart
void insertStr(String str) {
  final sel = selection;
  text = text.replaceRange(selection.start, selection.end, str);
  final len = str.length;
  selection = sel.copyWith(
    baseOffset: sel.start + len,
    extentOffset: sel.start + len,
  );
}
```

The `text` write is rejected by the read-only gate in `set value` →
`_getEditResultNotBreakingReadOnly`, which returns without applying the new
value. But `insertStr` then writes the selection **unconditionally**, so the
caret advances by `str.length` even though nothing was inserted.

Measured, on `e04c06f`, with the caret at the start of the first read-only line
of `'ro//readonly\nabc\nro//readonly\n'`:

| | before | after `enter` |
|---|---|---|
| `value.text` | `ro\nabc\nro\n` | `ro\nabc\nro\n` (unchanged — gate works) |
| `selection` | `TextSelection.collapsed(offset: 0)` | `TextSelection.collapsed(offset: 1)` |

So the read-only guarantee holds for the text, but the caret drifts. Pressing
`Enter` repeatedly walks the caret through the read-only region while nothing
changes, and the caret's final resting place depends on how many times the key
was pressed rather than on the document.

The same applies at the cursor positions exercised by the read-only tests: a
rejected `Enter` advances the caret by exactly one offset in every case observed
(`0 → 1`, `4 → 5`, `9 → 10`).

## Where it lives

`lib/src/code_field/code_controller.dart` — `insertStr` (line 515), reached from
`onEnterKeyAction` (line 628) via the `EnterKeyAction` wired in `code_field.dart`.
`onTabKeyAction` reaches the same `insertStr`.

## Why it was invisible

`test/src/code_field/code_controller_readonly_test.dart` drove typing through
direct value writes (`controller.value = controller.value.replacedSelection(...)`),
which the gate rejects **atomically** — text and selection alike, because the
value is never applied. Converting those to real `Enter` key events (fork issue
#120) is what exposed the split: the text is refused, the selection is not.

## Expected outcome

A rejected insertion should leave the caret where it was. Either `insertStr`
applies the selection only when the text write is accepted, or
`onEnterKeyAction` checks the read-only gate before touching the selection.

