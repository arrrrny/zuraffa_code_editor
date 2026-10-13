# Data model: cache-text-span

No persistent data, no serialisable entities, no schema. The entire change is one
piece of in-memory state on an existing controller. This document names it,
bounds its lifetime, and states what it is not.

## The state

Two private fields on `CodeController`:

| Field | Type | Meaning |
| --- | --- | --- |
| `_spanCacheKey` | `_SpanCacheKey?` | The inputs the cached span was built from; `null` until the first miss |
| `_cachedTextSpan` | `TextSpan?` | The object the last miss built and returned |

`_SpanCacheKey` is a **record type alias** (`typedef _SpanCacheKey = (Code,
TextStyle?, CodeThemeData?, Mode?, SearchResult, SearchNavigationState)`), not a
class. That is a deliberate choice, not brevity:

- Dart records get structural `==` and `hashCode` from the language, so there is
  no comparison code of ours to test, to keep correct, or to leave uncovered —
  the 100% line gate has nothing to chase.
- Record field comparison is pairwise `==`, which gives exactly the mixed
  semantics this key needs: `TextStyle` compares **by value**
  (`text_style.dart:1486`), `SearchResult` compares **by value** (it `extends
  Equatable`, `result.dart:5`), and `CodeThemeData`, `SearchNavigationState` and
  `Code` — which implement no `==` — compare **by identity**. Writing a class by
  hand would mean choosing, per component, between `==` and `identical`, and
  getting one wrong is a stale-render bug (R1).
- A record cannot be given a misleading accessor or an invariant a future edit
  can break.

`lastTextSpan` (`code_controller.dart:171`, `@visibleForTesting`) is **not** the
cache. It is assigned on every call, hit or miss, so "the last span returned"
stays true. Making the cache *be* `lastTextSpan` would let a test overwrite the
cache; the two fields are separate on purpose.

## Lifetime and invalidation

The entry lives from the first miss until the next miss. There is exactly one
eviction event: a key that does not compare equal. There is no timer, no size
bound, no explicit clear, and nothing to dispose — the cached tree is plain
immutable data with no native resources, so `CodeController.dispose`
(`:1402-1410`) is unchanged and does not need to release it.

Invalidation table (each row is a functional requirement in `spec.md`):

| What changed | Which key component moves | Result |
| --- | --- | --- |
| Typed a character | `_code` (new `Code` via `_updateCode`, R2) | rebuild |
| Fold / unfold | `_code` | rebuild |
| A different `style` | `style` (`TextStyle ==`) | rebuild |
| A `CodeTheme` appeared / changed value | `theme` (`CodeThemeData` identity) | rebuild |
| The `CodeTheme` ancestor was removed | `theme` → `null` | rebuild |
| Language set / cleared | `language` | rebuild |
| Search pattern typed | `searchResult` | rebuild |
| Next / previous match | `searchNavigationState` | rebuild |
| Search closed | both | rebuild |
| IME composition started / ended | — | the composing branch runs **before** the cache and is never cached |

## What the state is not

- **Not observable.** No getter, no notification, no `toString`, no counter. A
  cache that can be observed is a contract that must be documented.
- **Not shared.** One entry per `CodeController`; nothing static, nothing
  global. Two `CodeField`s sharing a theme share nothing else.
- **Not keyed on the rendered text.** The key is the *inputs*, not
  `visibleText`. Deriving the key from the output would require comparing span
  trees, which is exactly the work the cache exists to avoid.
- **Not a parse cache.** `Code` is rebuilt on every keystroke by
  `_updateCodeIfChanged`; this change caches the span tree above it, not the
  parse.

## The one documented hole

A host that passes a mutable `Map<String, TextStyle>` into `CodeThemeData` and
mutates it afterwards (`code_theme_data.dart:11-27` assigns into
`this.styles` after construction) changes the render without changing the key.
That is already true without the cache — `CodeTheme.updateShouldNotify`
(`code_theme.dart:23-25`) compares `data` by identity and would not fire either —
so this change does not introduce it. Recorded here, with `@immutable` on the
class as the existing promise, and not fixed by this spec.
