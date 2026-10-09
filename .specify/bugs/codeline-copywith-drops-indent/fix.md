# Fix: codeline-copywith-drops-indent

## Change

`lib/src/code/code_line.dart:40` — one line.

```diff
       CodeLine(
         text: text ?? this.text,
         textRange: textRange ?? this.textRange,
         isReadOnly: isReadOnly ?? this.isReadOnly,
-        indent: text == null ? 0 : _calculateIndent(text),
+        indent: text == null ? indent : _calculateIndent(text),
       );
```

When the caller does not pass `text`, the existing `indent` is carried forward;
when `text` *is* passed, `_calculateIndent` derives the indent from the new text,
exactly as `CodeLine.fromTextAndRange` and `CodeLine.fromTextAndStart` do. This
makes `copyWith` consistent with both constructors and removes the
"silently mutate a field you didn't ask about" behaviour.

## Why this is the minimal correct fix

The alternatives were:

- **Add `indent` as an optional `copyWith` parameter** — rejected. It would widen
  the public API for a value the class already derives itself, and the buggy
  call sites (`code.dart:181`, `:200`) still wouldn't pass it, so read-only
  sections would still lose their indent.
- **Recalculate from `this.text` when `text` is null** — equivalent in result but
  wasteful, and it would diverge from `indent` if a future constructor allowed a
  hand-set indent.
- **Drop `indent` from `copyWith` entirely by routing through the factories** —
  larger churn for no behavioural gain.

## Verification

- `flutter test test/src/code/code_line_copy_with_indent_test.dart` — 6/6 green
  with the fix; 2 fail on master.
- Full suite green, `dart analyze` clean, `dart format` clean.
- See `tdd/verification.md`.
