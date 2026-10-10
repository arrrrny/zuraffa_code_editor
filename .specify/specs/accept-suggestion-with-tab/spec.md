# Verification: accept an autocomplete suggestion with Tab (#36)

**Issue:** [arrrrny/zuraffa_code_editor#36](https://github.com/arrrrny/zuraffa_code_editor/issues/36) — synced from upstream `akvelon/flutter-code-editor#188`.
**Label:** `spec`

## Question

Does pressing Tab commit the highlighted autocomplete suggestion?

## Finding: yes — the behaviour already exists on this fork

`Tab` is bound in `lib/src/code_field/code_field.dart` to `TabKeyIntent`, whose
`TabKeyAction` calls `CodeController.onTabKeyAction()`
(`lib/src/code_field/code_controller.dart`). That method prefers
`insertSelectedWord()` while `popupController.shouldShow` and falls back to
inserting `tabSpaces` spaces otherwise. `onEnterKeyAction()` shares the same
preference, and the arrows are handled in `_onKeyDownRepeat`.

Upstream filed this in 2019 (`#188`); the fork has since implemented it. This
issue asked "make adding suggestion by tab key press", and it works.

## Deliverable

`test/src/code_field/tab_accepts_suggestion_test.dart` — 5 tests pinning the
behaviour so it cannot regress:

| Test | Pins |
|------|------|
| Tab accepts and hides the popup | the headline request |
| Tab accepts the arrowed-to suggestion, not the first | `selectedIndex` is honoured, not always index 0 |
| Enter still commits as well | the shared preference |
| Tab inserts the editor indent with no popup | the fallback |
| a disabled/never-shown popup is not an acceptance | `enabled == false` is not "showing" |

Fault-injected by removing the `popupController.shouldShow` branch from
`onTabKeyAction`: the two Tab acceptance tests go red, the rest stay green.
