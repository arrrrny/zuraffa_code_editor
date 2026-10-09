# Bug Issue: Missing mounted/disposed checks in post-frame callbacks and CodeController rebuild

- **Slug**: mounted-disposed-checks
- **Fetched**: 2026-10-09
- **Issue**: 4
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/4
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

## What was asked

The library uses `WidgetsBinding.instance.addPostFrameCallback` and uses the
context in the callback without checking if the state is actually still mounted.
Similarly, `CodeController.rebuild()` has an async gap before accessing the
context but does not check whether the controller has been disposed in the
meantime.

Synced from upstream flutter-code-editor:
- https://github.com/akvelon/flutter-code-editor/issues/299 — "[BUG] missing !mounted/disposed checks"

Upstream body verbatim:
```
The library uses `WidgetsBinding.instance.addPostFrameCallback` and uses the context in the callback without checking if the state is actually still mounted. This may not cause issues most of the time – but the time will come – and it did for me 🙈

Same thing with the CodeController, it has an async gap in `rebuild()` before accessing the context but it does not check if the controller has been disposed in the meantime. another 💣

Here is a pull request that fixes both of these: https://github.com/akvelon/flutter-code-editor/pull/298
```

## Why it matters

Unmounted context access throws after dispose (common when a CodeField is inside
a route that pops quickly, or a TabBarView / IndexedStack page switch), and a
disposed-controller access in the async gap throws `A CodeController was used
after being disposed` — both crash host apps and are hard to reproduce.

## Acceptance criteria

- [ ] Every post-frame callback that touches `context` guards with `if (!mounted) return;` (State) / the controller's disposed check (CodeController)
- [ ] A regression test proves disposing the widget before the post-frame callback fires does not throw
- [ ] A regression test proves calling controller methods during the dispose window does not throw

## Comments

None.
