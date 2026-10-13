# Research: cache-text-span

Fork issue: #114 · Upstream: akvelon/flutter-code-editor#127
Each item below is a claim that was checked against the code, with the check
named. Anything not checked here is not asserted anywhere in `spec.md`.

## R1 — Why returning the object, rather than an equal copy, is the whole point

Checked: `$_FLUTTER/packages/flutter/lib/src/rendering/paragraph.dart:422-446`,
Flutter 3.47.5 (revision `6a19cca564`).

```dart
  set text(InlineSpan value) {
    switch (_textPainter.text!.compareTo(value)) {
      case RenderComparison.identical:
        return;
      case RenderComparison.metadata:
        … markNeedsSemanticsUpdate();
      case RenderComparison.paint:
        … markNeedsPaint();
      case RenderComparison.layout:
        … markNeedsLayout(); _disposeSelectableFragments(); …
    }
  }
```

`InlineSpan.compareTo` (`text.dart`, `RenderComparison compareTo(InlineSpan other)`)
compares the two spans field by field and in children, and returns `identical`
only when they are the same instance. So:

- returning the **same instance** → `RenderParagraph` returns immediately: no
  relayout, no repaint, no semantics update, and the expensive
  `_disposeSelectableFragments` / `_updateSelectionRegistrarSubscription` work
  in the `layout` branch is skipped too;
- returning a structurally-equal **copy** → `paint` or `layout`: the tree is
  re-walked and the fragments are torn down and rebuilt.

Two consequences, both load-bearing:

1. The cache must store and return the object, never a copy. A copy is not a
   smaller win, it is worse than today in the `layout` case.
2. The same mechanism is what makes an **under-specified key a rendering bug**
   rather than a performance bug. If the key says "unchanged" while the rendered
   output changed, `RenderParagraph` returns on `identical` and the widget paints
   the stale tree. There is no framework backstop.

Corollary, recorded so nobody looks for one: `RenderParagraph` also has no
knowledge of `textScaler`, wrapping, or any of the other things that changed on
the *outside* of the span. Flutter handles those independently (a
`MediaQuery.textScaler` change rebuilds `RichText`, which re-assigns its own
`textScaler`), and the cache never participates in them — the span instance it
returns is a function of the inputs listed in `spec.md` §Decisions only.

## R2 — `Code` identity is a complete proxy for the document state

Checked: every assignment to `_code` in `lib/src/code_field/code_controller.dart`,
found with `grep -n '_code = '`:

| Line | Context | New instance? |
| --- | --- | --- |
| 291 | constructor initializer, `_code = Code.empty` | yes |
| 295 | constructor body, `_code = _createCode(text ?? '')` | yes |
| 389 | `set language`, `_updateCode(_code.text)` | yes |
| 896 | `applyHistoryRecord`, `record.code.foldedAs(_code)` | yes |
| 1171 | `_updateCode`, `newCode.foldedAs(_code, …)` | yes |
| 1214 | `foldAt`, `_code.foldedAt(line)` | yes |
| 1221 | `unfoldAt`, `_code.unfoldedAt(line)` | yes |
| 1242 | the folded-blocks pass (used by `foldBlocks`) | yes |

Eight sites, all of them assigning a freshly constructed `Code`. There is no
path that mutates a `Code` in place: `lib/src/code/code.dart:35-51` declares
every field `final` and there is no setter anywhere on the class.

`Code` therefore carries the text, the parse result, the folded blocks, the
hidden line ranges and the hidden ranges, and its identity changes iff one of
them is replaced. `hiddenRanges` (`lib/src/hidden_ranges/hidden_ranges.dart`) is
itself built from the folded set, so a fold change always reaches a new `Code`.

The complementary direction — an extra identity change that the key was not
counting — costs only a missed hit, so the key errs safe by construction.

## R3 — The theme component of the key, and the one hole

Checked: `lib/src/code_field/code_controller.dart:1379-1381`,
`lib/src/code_theme/code_theme.dart` (whole file, 26 lines),
`lib/src/code_theme/code_theme_data.dart:1-30`.

```dart
  CodeThemeData _getTheme(BuildContext context) {
    return CodeTheme.of(context) ?? CodeThemeData();
  }
```

`CodeTheme.of` is a `context.dependOnInheritedWidgetOfExactType` lookup that
returns `widget?.data`. `CodeThemeData`:

- is annotated `@immutable` but is **not** `const`-constructible;
- does not override `==`, so its equality is identity;
- has a constructor that *mutates* the field it just initialised:
  `: styles = styles ?? {} { … this.styles['class'] = classStyle; … }`.

So there are exactly two states for the theme in the key:

| `CodeTheme.of(context)` | Normalised key | Hits? |
| --- | --- | --- |
| `null` (no ancestor) | `null` | stable, so the cache works with no theme ancestor |
| a `CodeThemeData` | that instance | stable: `InheritedWidget` hands the same object to every dependent, and `updateShouldNotify` (`code_theme.dart:23-25`) only fires on `!=`, i.e. on identity change |

Keying the **raw `CodeTheme.of(context)` result** rather than the
`CodeThemeData()` that `_getTheme` fabricates is what makes the no-ancestor case
workable. Keying the fabricated object would produce a fresh instance on every
call, the cache would never hit, and — this is the part worth stating plainly —
**every test would still pass**, because a cache that never hits is
indistinguishable from no cache by any observable means. That is why FR-6 needs a
test that asserts a hit *with* a `CodeTheme` in scope and a hit *without* one,
and why the mutation audit includes "key on `_getTheme(context)` instead of
`CodeTheme.of(context)`".

The hole: a host that passes a `Map<String, TextStyle>` to `CodeThemeData` and
then mutates that map gets a new render without a new instance. That is already
true today without the cache (`updateShouldNotify` would not fire either, and
`@immutable` on the class is a promise the constructor breaks for that one field),
so the cache does not make it worse. Recorded as an accepted, pre-existing
condition rather than a new risk.

## R4 — The candidate key components, and why the list is exactly six

Checked by reading every value `buildTextSpan` (`:1332-1364`) can reach:

- `hasActiveComposition` — a getter on `TextEditingController`; gates the early
  `super.buildTextSpan` return. Kept **out** of the cache entirely (FR-10).
- `_createTextSpan` reads `_language` (`:1368`), `_getTheme(context)` (`:1371`)
  and `style` (`:1372`), and constructs `SpanBuilder(code: _code, …)`. Four
  components: `_language`, theme, `style`, `_code`.
- `_code.hiddenRanges.cutSearchResult(fullSearchResult)` — `fullSearchResult`
  (`:164`, `@internal`), and `_code` already in the key.
- `SearchResultHighlightedBuilder(searchResult:, rootStyle: style, textSpan:,
  searchNavigationState: _searchNavigationController.value)` — the value is
  already in the key; `_searchNavigationController.value` is a
  `ValueNotifier<SearchNavigationState>` reading.

That is six components total. Nothing else is read: there is no
`lineBackgroundBuilder`, no `readOnly`, no suggestion state on this path
(`lineBackgroundBuilder` is consumed by `LineBackgroundLayer`, a separate widget,
and `PopoverController` state does not reach the span).

Components considered and rejected:

- **`visibleSectionNames`** — it is a parameter of `Code`, so a change goes
  through a new `Code`. In the key it would be redundant.
- **`textEditingValue`** — `CodeController` keeps `super.value` in sync with
  `_code.visibleText` through `_getValueWithCode`, so it moves iff `_code` moves.
  Redundant, and comparing it would mean comparing a `TextEditingValue` with a
  `TextSelection`, which has no cheap `==`.
- **A version counter bumped in `_updateCode`** — more machinery to keep correct
  than the identity check it would replace, and it would go stale the moment a
  new `_code =` site is added without a matching bump. R2's enumeration is the
  cheaper invariant, and FR-4 is the test that would catch a new site.

## R5 — The consumer does not mutate the cached tree

Checked: `lib/src/code_field/search_result_highlighted_builder.dart` (whole
file, 152 lines) and `lib/src/code_field/span_builder.dart`.

`SearchResultHighlightedBuilder.build()`:

- `:93-95` — with no matches, `return textSpan;`: the input span is handed back
  untouched, and it is the object `SpanBuilder.build()` returned.
- `:97-104` — otherwise it walks the input with `visitChildren` and only reads
  `span.text` and `span.style`.
- `:120-151` — `_processText` adds **new** `TextSpan`s built from `substring`
  results to `_spans`; nothing is written into an existing span.

The builder is one-shot: `_spans` (`:57`) accumulates and is never cleared, and
`matchIndexes` is `late final`. Calling `build()` twice on one instance would
interleave two trees' leaves. The cache therefore constructs a new builder on
every miss — which is what the current code already does — and FR-9 pins that the
second call's leaf count equals the first's.

`SpanBuilder.build()` allocates a fresh tree and does not retain a reference, so
the object stored in the cache is not reachable from anywhere else.

## R6 — What this does not fix

- **`_updateCode` still re-parses on every keystroke.** The cache is one level
  above parsing; typing a character produces a new `Code` and therefore a new
  tree. A parse cache is a different issue with a different risk profile.
- **`EditableText`'s other per-rebuild work** (`_buildTextSpan` also merges
  styles and builds a `TextSpan` parent) is untouched.
- **The search path allocates more, not less, when a search is active**, because
  every keystroke in the search field changes `fullSearchResult` and therefore
  invalidates. Correct, and the reason `fullSearchResult` is in the key.
