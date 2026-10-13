# Spec: cache-text-span

Fork issue: #114 · Upstream: akvelon/flutter-code-editor#127
Label: `spec` · Severity: `low` · Backlog rank: 17

## What was asked

"Memoise the span so identical inputs return the cached object instead of
rebuilding."

The upstream issue is one sentence long, and the repository already carries the
matching TODO at `lib/src/code_field/code_controller.dart:1355`:

```dart
// TODO(alexeyinkin): Return cached if the value did not change, https://github.com/akvelon/flutter-code-editor/issues/127
```

## What exists today

`CodeController.buildTextSpan` (`lib/src/code_field/code_controller.dart:1332-1364`)
is the `TextEditingController.buildTextSpan` override that `EditableText` calls
to obtain the text it paints. Flutter calls it from
`EditableText._buildTextSpan` on **every rebuild** — and `EditableText` rebuilds
on selection changes, focus changes, scroll-offset-notifying events and every
parent rebuild, not only when the text changes. Each call does all of:

1. `_createTextSpan` → `SpanBuilder(code:, theme:, rootStyle:).build()`, a full
   walk of the parsed highlight tree, allocating a parallel `TextSpan` tree for
   every node in it.
2. `_code.hiddenRanges.cutSearchResult(fullSearchResult)`.
3. `SearchResultHighlightedBuilder(...).build()`, a second full walk that
   flattens the tree into new `TextSpan` leaves when there are matches.

So a scroll notification that rebuilds `EditableText` re-parses nothing but does
re-walk and re-allocate the entire tree for an unchanged document. The result of
step 3 is also assigned to `lastTextSpan` (`:171`, `@visibleForTesting`), which
**has no reader anywhere in `lib/` or `test/`** (verified by grep) — so nothing
in the existing suite asserts how often the tree is rebuilt, and nothing in it
depends on getting a fresh instance.

## What this spec adds

A single-entry cache in `buildTextSpan`. The first call for a given input builds
as today; a subsequent call with an unchanged input returns the object the
previous call returned, without walking or allocating anything.

The cache is **invisible when the input changed and invisible when nothing
changed** — its entire observable surface is *which instance* comes back. That
is the thing tested, and it is the thing the mutation audit will hunt.

## Decisions

- **The cache key is the set of everything `buildTextSpan` reads, and nothing
  else.** An under-specified key is the one way this change can corrupt
  rendering: if a key says "unchanged" while something in the rendered output
  changed, `RenderParagraph` takes the `identical` fast path
  (see `research.md` R1) and paints the stale tree. The key is:

  | Component | Why it is in the key | Comparison |
  | --- | --- | --- |
  | `_code` | text, parse result, folded blocks and hidden sections all live here | identity — see R2 |
  | `style` | forwarded into every span as `rootStyle` | `==` (`TextStyle` implements value equality) |
  | theme | `SpanBuilder` reads `theme.styles[…].style` per node | see R3 |
  | `_language` | chooses `SpanBuilder` vs the plain `TextSpan(text: text)` path | `==` (`Mode`) |
  | `fullSearchResult` | drives the highlight flattening | identity |
  | `_searchNavigationController.value` | selects which match is "current" | identity |

  `hasActiveComposition` is handled *before* the cache: that branch returns
  `super.buildTextSpan` and is not cached, because its output depends on the
  composing range, which is not in the key.

- **A cache hit returns the previously returned object, not a copy.** The issue
  asks for "the cached object". Returning a copy would defeat the point:
  `RenderParagraph.text`'s `compareTo` result for a structurally-equal copy is
  `paint` or `layout`, not `identical` (`research.md` R1), so the copy would
  still force a repaint. The cache is therefore a `TextSpan?` field plus a key
  record, compared field by field — there is no attempt to compare the trees
  themselves.

- **The theme is normalised before it enters the key.** `_getTheme`
  (`:1379-1381`) returns `CodeTheme.of(context) ?? CodeThemeData()`, and
  `CodeThemeData` (`lib/src/code_theme/code_theme_data.dart:4`) neither is
  `const`-constructible nor overrides `==`. Without normalisation, a field with
  no `CodeTheme` ancestor would get a fresh instance on every call and the cache
  would never hit — a silent no-op that makes every test still pass. The
  normalised key is the `CodeTheme.of(context)` result itself, which is `null`
  for the no-ancestor case (one stable value), and a stable `CodeThemeData`
  identity otherwise because `InheritedWidget` hands the same instance to every
  dependent. `research.md` R3 records the one hole this leaves (an externally
  mutated `styles` map) and why it is already the existing behaviour.

- **`Code` identity is a complete proxy for the document state, so the key does
  not decompose it.** `_updateCodeIfChanged` (`:1163-1176`) early-returns when
  the text is unchanged, and every mutation path installs a new `Code`:
  `_updateCode` (`:1171`), `foldedAs` (`:896`, `:1171`), and the three direct
  assignments at `:1214`, `:1221`, `:1242`. Identity therefore covers text,
  parse, folds and hidden sections at once, and it is the cheapest component to
  compare. The failure mode of an *extra* identity change is only a missed hit.
  `research.md` R2 verifies the claim by enumerating every `_code =` site.

- **The cache holds one entry, not a map.** A keyed map would be a memory
  commitment with no measured benefit: `buildTextSpan` is called in a tight loop
  by one widget with one input at a time. One entry is the whole win and has an
  obvious eviction rule (replace).

- **The cached tree is never mutated.** This is a constraint on the cache's
  consumer, not on the cache, and it is verified rather than assumed:
  `SearchResultHighlightedBuilder.build()`
  (`lib/src/code_field/search_result_highlighted_builder.dart:92-110`) either
  returns its input span untouched (no matches, `:93-95`) or builds a brand-new
  `TextSpan` tree of new leaves from new `substring` results (`:120-151`); it
  never writes into the tree it was handed. `SpanBuilder.build()` likewise only
  allocates. So the object handed to `EditableText` is immutable in practice and
  safe to re-hand.

- **No public API, no new field, no configurability.** No `bool enableCache`,
  no `clearCache()`, no parameter on `CodeField`. A cache the host cannot turn
  off and cannot observe is the only kind worth shipping: the moment it is
  observable, its key must be documented as a public contract.

- **`lastTextSpan` keeps its meaning.** It stays "the last `TextSpan` returned
  from `buildTextSpan`", which on a cache hit is the cached object. Its doc
  comment says it "can be used in tests to make sure that the updated text was
  actually requested by the widget" — with the cache that inference is no longer
  valid (a hit returns the old object without requesting anything), so the doc is
  corrected rather than left misleading. This is the one documentation change in
  the PR.

## Out of scope

- Caching anything else: not `SpanBuilder`'s tree, not `Code`, not the search
  result. `SpanBuilder` is `@internal`-adjacent (not in the barrel) and has other
  callers in tests; a cache there would need its own key.
- Multi-entry or LRU caching, cache statistics, hit-rate instrumentation.
- Any change to `SpanBuilder`, `SearchResultHighlightedBuilder`,
  `HiddenRanges.cutSearchResult` or the folding machinery.
- Warm-up or precomputation at parse time.
- Anything observable: no new getter, no notification, no assertion.

## Assumptions

- **Flutter's `RenderParagraph` treats an identical span instance as
  "nothing to do".** `paragraph.dart:422-446` (`set text(InlineSpan value)`)
  switches on `_textPainter.text!.compareTo(value)` and returns immediately on
  `RenderComparison.identical`. This is the mechanism the whole change leans on,
  and it is read from the installed 3.47.5 framework, not assumed. It also bounds
  the benefit: `compareTo` returning `metadata` or `paint` for a structurally
  equal *copy* means a copy would be strictly worse than the object.
- **`EditableText` may call `buildTextSpan` when nothing changed.** The claim
  motivating the issue. Whether it happens often in this codebase is not measured
  and does not need to be: a one-entry cache is correct under either answer.
- **A cache miss costs what a miss costs today.** The key comparison is six field
  comparisons, one of which (`TextStyle ==`) walks a dozen properties. That is
  bounded and tiny next to a tree walk, and it is paid on the typing path too —
  recorded so it is not discovered later.
- **`SearchResultHighlightedBuilder` is one-shot.** Its `_spans` list
  (`:57`) accumulates, so a single builder instance cannot `build()` twice. The
  cache must therefore construct a *new builder* per miss, which it does; the
  bug this would cause (spans from an earlier call leaking into a later tree) is
  exactly what FR-7 pins.
- **`style` is value-comparable.** `TextStyle` implements `==`. If a future
  Flutter removes that, the key degrades to "always miss", which is safe.

## Functional requirements

- **FR-1** Two consecutive `buildTextSpan` calls with no intervening change to
  the controller return the **same object** (`identical`), not an equal one.
- **FR-2** The same holds across a `notifyListeners()` that changes nothing the
  span depends on — e.g. a `CodeController` notification driven by selection.
- **FR-3** Changing the text invalidates: a typed character produces a different
  object, and that object's plain text contains the new character.
- **FR-4** Folding or unfolding invalidates.
- **FR-5** Changing `style` invalidates.
- **FR-6** Changing the `CodeTheme` in scope invalidates. This is the case the
  naive identity key gets wrong; see Decisions and `research.md` R3.
- **FR-7** Changing the search state invalidates: opening the search with a
  pattern, navigating to the next match, and closing the search each produce a
  different object, and the highlighted match follows `searchNavigationState`.
- **FR-8** Changing the language invalidates.
- **FR-9** A cache hit does not accumulate: with an active search, the second
  call returns a tree with exactly the same number of leaves as the first, i.e.
  the builder is reconstructed per miss and not reused (`Assumptions`).
- **FR-10** During an active IME composition the composing-aware path is taken
  and is not served from the cache: the composing span is rebuilt each call, and
  the composing range survives.
- **FR-11** The tree a hit returns is structurally what a miss builds: the same
  plain text, the same leaf count, and the same per-leaf styles, so the cache
  cannot change rendering.
- **FR-12** `lastTextSpan` is still assigned on every call, hit or miss, and is
  the object that was returned.
- **FR-13** The no-language path is cached too, and invalidates on text change.

## Success criteria

- **SC-1** `dart analyze --fatal-infos lib test` clean.
- **SC-2** `dart format --output=none --set-exit-if-changed .` clean.
- **SC-3** `flutter test --concurrency=2` — every pre-existing test passes
  unmodified.
- **SC-4** `tool/coverage_gate.py --min 100` stays at 100.00% with the
  `EXEMPT_LINES` set unchanged, or renumbered only for lines the new file itself
  shifts.
- **SC-5** A mutation audit of the cache logic reports 0 survivors, with the
  audit script committed under `.specify/specs/cache-text-span-114/tdd/`.
- **SC-6** A new test file exercises FR-1 … FR-13, written RED before the
  implementation.
