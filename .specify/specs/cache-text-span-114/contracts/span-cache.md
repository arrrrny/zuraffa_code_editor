# Contracts: the span cache

There is no wire format and no public signature. The contract is behavioural, and
it has exactly two clauses.

## Clause 1 — What a call returns

`CodeController.buildTextSpan(context:, style:)` returns a `TextSpan`.

- When the six key components (`data-model.md`) all compare equal to the previous
  call's, it returns **the same object** the previous call returned.
- Otherwise it returns a freshly built tree.

`TextEditingController.buildTextSpan` is the framework's contract; this change
adds an identity guarantee on top of it and removes nothing from it. In
particular the returned tree is still the flattened, search-highlighted,
fold-marker-carrying tree it always was — `RenderParagraph` receives the same
*content* either way.

## Clause 2 — What a caller must not do

**The returned object must not be mutated.** This clause already held before the
change, but a cache makes violating it visible: mutating the tree that a later
hit re-hands out corrupts every subsequent render.

Nothing in this package violates it, verified by reading rather than by promise:

- `SpanBuilder.build()` allocates a new tree and keeps no reference.
- `SearchResultHighlightedBuilder.build()`
  (`lib/src/code_field/search_result_highlighted_builder.dart:92-110`) either
  returns its input untouched or builds new leaves from `substring` results
  (`:120-151`).
- Flutter's `TextPainter` / `RenderParagraph` only read the tree.

If a future change needs to mutate a span it gets from `buildTextSpan`, it must
either copy first or stop reading from `buildTextSpan`. This is the sentence that
belongs in the review of any such change.

## Clause 3 — What is not part of the contract

- **The number of calls.** No caller may rely on `buildTextSpan` being invoked a
  particular number of times. `lastTextSpan` exists to assert that the text was
  *requested*, and a cache hit means it was not; its doc is corrected accordingly
  so nobody re-derives a call-count assertion from it.
- **The instance identity across a theme restyle.** A new `CodeThemeData` with
  equal contents invalidates (identity), so a host that rebuilds its theme on
  every frame gets a rebuild every frame. That is today's behaviour and it is
  preserved deliberately: value equality on a theme would be a claim the package
  does not make.
