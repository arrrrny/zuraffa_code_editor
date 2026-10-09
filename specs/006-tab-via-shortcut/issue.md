# Spec Issue: Handle Tab through Flutter shortcuts/actions

- **Slug**: tab-via-shortcut
- **Number**: 006
- **Fetched**: 2026-10-09
- **Issue**: 29
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/29
- **State**: open
- **Author**: arrrrny
- **Labels**: spec

## Body

Upstream body verbatim:

```
Currently, when `Tab` is pressed, it is processed like this:
https://github.com/akvelon/flutter-code-editor/blob/1ea2b9efc816c22a58359e571256d9496f97215f/lib/src/code_field/code_controller.dart#L174

We should employ Flutter's shortcuts instead:
https://docs.flutter.dev/development/ui/advanced/actions_and_shortcuts
```

Synced from upstream `akvelon/flutter-code-editor#21 — "Handle tab via shortcut"`.

## Why it matters

Handling Tab inside the controller bypasses Flutter's `Shortcuts`/`Actions`
system, so Tab cannot be remapped and it steals focus traversal that users
expect in forms. Routing it through shortcuts is the platform-correct
mechanism and composes with other key bindings.

## Acceptance criteria

- [ ] Tab handling moves into a `Shortcuts`/`Actions` widget (or documented equivalent) instead of an ad-hoc controller hook
- [ ] Existing behavior (indent on Tab) is preserved, covered by tests
- [ ] Consumers can override or disable the binding

## Comments

None.
