# Bug Issue: Line numbers escape the widget and never scroll (`_numberScroll` unused)

- **Slug**: line-numbers-escape-widget
- **Fetched**: 2026-10-09
- **Issue**: 19
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/19
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
![image](https://github.com/akvelon/flutter-code-editor/assets/30291302/6d684549-4d6b-41ac-9170-12ea9d3370e5)


Also, why is the line numbers side bar so... wide?!
```

Synced from upstream `akvelon/flutter-code-editor#259 — "Line Numbers escape the widget"`.

## Why it matters

The gutter visually detaches from the code area and does not follow scrolling,
so line numbers point at the wrong lines. The reporter traced this to the
`_numberScroll` `ScrollController` being declared but never wired to anything.

## Acceptance criteria

- [ ] Root cause identified in `lib/src/line_numbers/gutter.dart` (or wherever `_numberScroll` lives): is the controller attached to the gutter's scroll view?
- [ ] Gutter scrolls in lockstep with the code area
- [ ] A regression test pins gutter/code scroll sync (or documents why a widget test cannot observe it)

## Comments

- TekExplorer: "Turns out they don't even scroll. What the hell is `_numberScroll` for if you don't even use it?!" — "as long as you don't wrap the entire code field in a scroll view, it happens continuously. I know it does because I checked the implementation code and `_numberScroll` isn't used *at all*".
- alexeyinkin: asked for platform, repro, `flutter doctor -v` (never supplied).
