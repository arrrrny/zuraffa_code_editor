# Bug Assessment: Page up / Page down does not scroll the CodeField

- **Slug**: page-up-down-does-not-scroll
- **Created**: 2026-10-10
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/27
  (upstream akvelon/flutter-code-editor#195, empty body)
- **Verdict**: valid, reproduced
- **Severity**: medium

## Symptom

PageUp / PageDown do nothing in a focused `CodeField`.

## Root Cause

Flutter binds these keys at the **app** level
(`DefaultTextEditingShortcuts`): PageUp/Down → `ScrollIntent(type: page)`
(or `ExtendSelectionVerticallyToAdjacentPageIntent` on macOS). The
matching `ScrollAction` resolves the scrollable with `Scrollable.of`,
which walks **up** from the context it was found in — the app root — and
never sees the editor's own scrollable, which lives *below* the CodeField.
The intent is therefore dispatched to a scrollable that either does not
exist or is the wrong one: the keypress silently no-ops.

This was masked for a long time by #42: before the field was bounded to
its viewport it had no internal scroll extent at all, so there was
nothing a page scroll could have moved.

## Reproduction

Widget test: 40 lines in a 200px-tall field, focus, `pageDown` → the
Scrollable inside the `EditableText` must scroll by one viewport (200);
`pageUp` returns it to 0. Without the fix the measured offset is 96px —
a different (wrong) scrollable answering the app-level intent.

## Proposed Remediation

- Add `PageScrollIntent(forward: bool)` + `PageScrollAction` to
  `lib/src/code_field/actions/`.
- Bind PageUp/PageDown to it in `CodeField`'s own shortcut map.
- Wire the action from the state: it animates `_codeScroll` by one
  editor-box height, which drags the linked gutter along.
- No caret movement — the issue asks for scrolling only.
