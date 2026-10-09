# Assessment: CodeLine.copyWith drops `indent` whenever `text` is not passed

- **Slug**: codeline-copywith-drops-indent
- **Discovered**: 2026-10-10
- **Found by**: coverage ratchet audit of `lib/src/code/code_line.dart` (not a
  user-reported upstream issue — the bug is latent in upstream too)
- **Severity**: medium (wrong behaviour, no crash)
- **Labels**: bug

## Symptom

`CodeLine.copyWith` is declared as a partial-override helper: callers pass only
the fields they want to change. But its `indent` parameter is not part of the
signature, and the body computes it from `text` unconditionally:

```dart
CodeLine copyWith({String? text, TextRange? textRange, bool? isReadOnly}) =>
    CodeLine(
      text: text ?? this.text,
      textRange: textRange ?? this.textRange,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      indent: text == null ? 0 : _calculateIndent(text),   // <-- bug
    );
```

So **every call that does not pass `text` silently resets the line's indent to
0**. `copyWith` therefore is not a no-op for the fields it doesn't mention — it
mutates a fourth field.

## Root cause

The `indent: 0` branch is a stale leftover from before `indent` became a
constructor-computed field (`CodeLine.fromTextAndRange` /
`CodeLine.fromTextAndStart` both derive it via `_calculateIndent(text)`). Once
those factories existed, the ternary should have read
`text == null ? indent : _calculateIndent(text)` — preserve the existing value
when the caller isn't replacing the text.

## Blast radius

Only two call sites invoke `copyWith` without `text`, and both are in
`lib/src/code/code.dart`:

- `code.dart:181` — `_makeCodeReadonly`, marks **every** line read-only.
- `code.dart:200` — `_applyNamedSectionsToLines`, marks the lines of each named
  read-only section (`readOnlySectionNames`) read-only.

Both call `lines[i].copyWith(isReadOnly: true)`, i.e. neither passes `text`, so
**every line inside a named read-only section has its indentation zeroed**.

`indent` is consumed in exactly one place — `lib/src/folding/parsers/indent.dart`,
which drives indent-based foldable-block detection (`IndentFoldableBlockParser`).
Consequences:

- Indent folding is wrong for read-only sections: the foldable-block boundaries
  are computed from indent 0 instead of the real indentation, so blocks inside a
  read-only section fold incorrectly (or not at all).
- Any future consumer of `CodeLine.indent` inherits the same corruption.

No user-visible crash: this is silent misbehaviour.

## Why it wasn't caught

`test/src/code/code_line_test.dart` had no `copyWith` coverage at all (that file
is part of the round-2 coverage work), and the existing
`.specify/bugs/folding-hides-next-block-start` suite does not combine read-only
sections with indentation.

## Acceptance criteria

- [x] `copyWith(isReadOnly: ...)`/`copyWith(textRange: ...)` preserves `indent`
- [x] `copyWith(text: ...)` still recalculates `indent` from the new text
- [x] A named read-only section keeps its real indentation after
      `Code(... readOnlySectionNames: ...)`
- [x] Regression tests pin both directions (preserve + recalculate)
- [x] Full suite, `dart analyze`, `dart format` clean

## Out of scope

- `operator ==` / `hashCode` omit `indent` (so two lines differing only in
  indent compare equal). That is a separate, pre-existing inconsistency; fixing
  it would ripple into tests and is recorded here explicitly rather than folded
  into this fix.
- `toString()` omits `indent` too — cosmetic, left alone.
