# Verification: handle Tab through Flutter shortcuts/actions (#29)

**Issue:** [arrrrny/zuraffa_code_editor#29](https://github.com/arrrrny/zuraffa_code_editor/issues/29) — synced from upstream `akvelon/flutter-code-editor#21`.
**Label:** `spec`

## Question

The issue links at `CodeController`'s raw key handler and asks for `Tab` to be
moved onto Flutter's [`Shortcuts`](https://docs.flutter.dev/development/ui/advanced/actions_and_shortcuts)
machinery instead.

## Finding: yes — the behaviour already exists on this fork

`CodeField` (`lib/src/code_field/code_field.dart`) builds a
`FocusableActionDetector` whose `shortcuts` map is assembled from two tables:

- `_shortcuts` — always on. Tab → `IndentIntent`, Shift+Tab → `OutdentIntent`,
  Ctrl+/ → `CommentUncommentIntent`, Ctrl+F / Cmd+F → `SearchIntent`, plus the
  copy/cut/undo/redo and page-scroll entries.
- `_shortcutsIgnoredWhileComposing` — added only when no IME composition is in
  progress. Escape → `DismissIntent`, **Enter → `EnterKeyIntent`**,
  **Tab → `TabKeyIntent`**. This second Tab entry overrides the `IndentIntent`
  one in the merged map, which is why a plain Tab inserts the editor indent
  through `TabKeyAction` rather than through `indentSelection()`.

`CodeController.actions` (`lib/src/code_field/code_controller.dart`) answers
every one of those intents with its action, and `CodeController.onKey` owns no
Tab or Enter branch at all — its `_onKeyDownRepeat` handles Ctrl+F and the
autocomplete popup's arrows and returns `ignored` for everything else, which is
what hands the character-shaped keys to the shortcut table.

## Deliverable

`test/src/code_field/tab_through_shortcuts_test.dart` — 11 tests:

| Test | Pins |
|------|------|
| Tab is `ignored` by `onKey`; Shift+Tab is, with the modifier held | the negative the issue asks for: the raw path owns no Tab/Enter branch and does not inspect modifiers to decide |
| Enter is `ignored` | the same negative for Enter |
| the arrows outside the popup are `ignored` | the boundary of what the raw path does own |
| while composing, every key is `ignored` — Ctrl+F included | the composing guard sits above the Ctrl+F branch; the ctrl is held through the framework, because the `keyF` leg with the modifier up is ignored either way |
| Ctrl+F opens the search and is `handled` | `onKey` is not empty — it just does not own the character-shaped keys |
| every one of the ten declared intents is answered by an action | the intent → action table, copy/undo/redo included |
| the actions share the controller that dispatches them | no action is wired to a foreign controller |
| a real Tab inserts the editor indent | the shortcut table delivers the edit |
| a real Shift+Tab outdents the caret line | `OutdentIntent` is reachable from the keyboard |
| a real Enter breaks the line | `EnterKeyIntent` is reachable from the keyboard |

Fault-injected twice. Removing the composing early-return reddens only the
composing-Ctrl+F test — Tab and Enter have no raw branch to fire either way, so
the modifier is what makes the guard visible. Adding a Tab branch to
`_onKeyDownRepeat` reddens the first two.

The negative is the point: a regression that moved Tab back into a raw handler
would leave every behavioural test green, because the observable effect of a
Tab is identical either way.
