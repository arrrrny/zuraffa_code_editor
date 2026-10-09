# Bug Issue: Tab renders as a tofu box in CanvasKit

- **Slug**: tab-tofu-canvaskit
- **Fetched**: 2026-10-09
- **Issue**: 20
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/20
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
<img width="465" alt="Screen Shot 2022-09-14 at 16 18 01" src="https://user-images.githubusercontent.com/31556582/190347288-d1a6c101-87de-4ed7-88c6-10fb9767d3bd.png">

Flutter issue: https://github.com/flutter/flutter/issues/79153

As a temporary solution, tabs are replaced with spaces on loading (https://github.com/akvelon/flutter-code-editor/pull/66) and editing (with TabModifier).
```

Synced from upstream `akvelon/flutter-code-editor#67 — "Tab is rendered as an unknown symbol (tofu) in CanvasKit"`.

## Why it matters

Tofu boxes in place of tabs make code unreadable. Upstream closed the loop:
the rendering fault was in Flutter itself (flutter/flutter#79153), fixed on
the Flutter master channel in September 2022, and upstream said it would keep
the issue open only until the fix reached stable and the pubspec floor could
be raised. This fork's floor is Flutter >= 3.10 (well past that fix), and the
editor already replaces tabs with spaces on load and on Tab keypress.

## Acceptance criteria

- [ ] Verify the current tab path (load + edit) still replaces tabs with spaces, so no tofu can render
- [ ] If the replacement path is intact, close as already-fixed with the evidence
- [ ] Otherwise add the missing replacement/rendering path plus a regression test

## Comments

- loic-sharma: fixed on Flutter master channel (repro: `Text('A\rB\tC')` rendering a box on stable, correct on master).
- alexeyinkin: "we confirm it is fixed now... we will keep it open until this lands in the stable channel and we update `pubspec.yaml` to require that as minimal."
