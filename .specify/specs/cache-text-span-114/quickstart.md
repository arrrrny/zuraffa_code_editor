# Quickstart: cache-text-span

## Reproduce the waste

Pump an editor over a document with a language set, then rebuild it without
changing anything, and count how many times a new span tree is built. Before this
change the count goes up on every rebuild; after, it does not.

```dart
final controller = createController('void main() {}\n');
await wt.pumpWidget(createApp(controller, focusNode));
final ctx = wt.element(find.byType(CodeField));

final a = controller.buildTextSpan(context: ctx, style: const TextStyle());
final b = controller.buildTextSpan(context: ctx, style: const TextStyle());
// before: !identical(a, b) — two trees for one document
// after:  identical(a, b)
```

## The change, in full

`lib/src/code_field/code_controller.dart` only. See `plan.md` §The shape of the
change — the diff is a private record alias, two fields, a key, an `if`, and a
store.

## Run the gates

```sh
flutter test test/src/code_field/build_text_span_cache_test.dart --concurrency=2
flutter test --concurrency=2
dart analyze --fatal-infos lib test
dart format --output=none --set-exit-if-changed .
bash /tmp/gate.sh /Users/arrrrny/Developer/zuraffa_114 /tmp/gate114.log
python3 .specify/specs/cache-text-span-114/tdd/mutation_audit.py
```

## What to look at when it breaks

- **A hit returns a stale tree.** Something in the render changed but not in the
  key. Add the missing component; do not widen the cache.
- **The cache never hits.** The key contains a value that changes on every call.
  The known trap is the theme — `CodeTheme.of(context)` returns `null` when there
  is no ancestor, `_getTheme` fabricates a `CodeThemeData()`, and that class has
  no `==` (`research.md` R3).
- **`RenderParagraph` skips a needed update.** Same root cause as the first case;
  `paragraph.dart:422-446` returns on `RenderComparison.identical` with no
  backstop.
