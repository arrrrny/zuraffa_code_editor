# Issue: Scrolling the suggestion list scrolls the editor too

- **Number**: 101
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/101
- **Upstream**: https://github.com/akvelon/flutter-code-editor/issues/190
- **Labels**: bug, severity:medium
- **Backlog rank**: 4
- **Created**: 2026-10-11

## What is wrong / missing (as filed)

The popup's scroll does not consume the gesture, so it propagates to the
editor's scroll view after the list reaches its end.

## Where it lives (as filed)

`lib/src/autocomplete/popup.dart` (this package: `lib/src/wip/autocomplete/popup.dart`).

## Reproduction (as filed, upstream #190)

A screen recording (June 2022, Flutter 3.0) shows the suggestion list scrolling
and the editor scrolling with it.
