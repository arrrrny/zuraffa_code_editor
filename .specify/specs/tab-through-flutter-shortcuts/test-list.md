# Test list — Tab through Flutter shortcuts/actions (#29)

1. `Tab is ignored, so the framework shortcut table dispatches it` — the issue's
   ask, pinned from the other side. RED if a Tab branch is added back to
   `_onKeyDownRepeat`.
2. `Shift+Tab is ignored too, modifiers and all` — the raw path does not inspect
   modifiers, so Shift+Tab reaches it as the same logical key. Same fault.
3. `Enter is ignored` — RED if `onKey` grows an Enter branch.
4. `an upward or downward arrow outside the popup is ignored` — pins the
   boundary of the raw path: the arrows are only owned while the popup shows.
5. `while composing, every key is ignored` — RED if the composing early-return
   in `onKey` is removed.
6. `Ctrl+F is the one shortcut the raw path owns and it opens the search` — RED
   if the `isCtrlF` branch in `_onKeyDownRepeat` is removed. Guards against the
   file reading as "onKey is empty", which would be a claim about the code that
   is not true.
7. `every intent CodeController declares is answered by an action` — RED if an
   intent is dropped from the `actions` map, which is the failure a consumer
   adding their own shortcut entry would hit.
8. `the actions share the controller that dispatches them` — RED if an action is
   constructed with a different controller.
9. `a real Tab inserts the editor indent` — RED if the Tab shortcut entry is
   removed from the field's table, or if Tab stops reaching an action. Also the
   end-to-end half of the issue.
10. `a real Shift+Tab outdents the caret line` — RED if the Shift+Tab entry is
    removed.
11. `a real Enter breaks the line through the action, not the raw path` — RED if
    the Enter entry is dropped from `_shortcutsIgnoredWhileComposing`.
