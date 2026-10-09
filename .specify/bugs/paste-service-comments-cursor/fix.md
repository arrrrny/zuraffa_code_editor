# Fix: paste-service-comments-cursor

## Change

`lib/src/code_field/code_controller.dart:542-553` — one branch, no new API.

```diff
       if (newValue.text != _code.visibleText) {
-        if (newValue.text.length > _code.visibleText.length) {
+        if (newValue.selection.isCollapsed &&
+            newValue.text.length > _code.visibleText.length) {
+          newValue = TextEditingValue(
+            text: _code.visibleText,
+            selection: _code.hiddenRanges.cutSelection(selectionSnapshot),
+          );
+        } else if (newValue.text.length > _code.visibleText.length) {
           // Manually typed in a text that has become a hidden range.
           newValue = newValue.replacedText(_code.visibleText);
         } else {
```

## Why

The `length >` branch previously threw away `selectionSnapshot` — the caret
already recovered into the full text, where the framework's offset is still
meaningful — and rebuilt the caret from a text diff
(`replacedText` → `collapsed(getChangedRange(...).start)`). That heuristic is
correct for a *single character* that turns a line hidden, because the changed
range is exactly the newly hidden text. It is wrong for a multi-line paste,
where the changed range spans every service comment inside the pasted run, so
its `start` is the first comment of the paste.

The fix routes the collapsed-caret case through the same
`recover` → `cut` round trip the unfold branch already uses (lines 548-552 of
the same block), so the caret survives.

## Why the `isCollapsed` guard

The `length >` branch serves two different edits:

- **collapsed caret** — a paste, or typing at the end of a run. The framework
  has already placed the caret at the end of what it inserted, and that offset
  is meaningful in the full text. It must be preserved.
- **non-collapsed selection** — `replacedSelection` of a run that turns into a
  service comment. Here the old collapse-to-start behaviour is what the
  existing tests pin (`code_controller_folding_editing_test.dart`
  "When deleting 2nd identical folded block, 1st one incorrectly folds",
  upstream-`TODO`-marked; `code_controller_hidden_ranges_test.dart`
  "A typed-in service comment becomes a hidden range"), and it is arguably
  right: there is no "end of an inserted run" to speak of.

`isCollapsed` distinguishes exactly those two, so no pinned behaviour changes.
Empirically, the *unified* rule (`cutSelection` for both) breaks exactly the
"deleting 2nd identical folded block" test (expected `collapsed(offset: 13)`,
got `(25, 26)`) — that test is the reason for the guard, and it is not touched
here.

## Post-review adjustment

The diff above shipped in `40925fc`. Review noted that the collapsed arm and
the unfold arm had identical bodies, so the conditional collapsed to two arms:

```diff
       if (newValue.text != _code.visibleText) {
-        if (newValue.text.length > _code.visibleText.length) {
+        if (!newValue.selection.isCollapsed &&
+            newValue.text.length > _code.visibleText.length) {
           // Manually typed in a text that has become a hidden range.
           newValue = newValue.replacedText(_code.visibleText);
         } else {
-          // Some folded block is unfolded.
+          // A paste, or a folded block is unfolded: the framework's caret
+          // offset is meaningful in the full text — keep it.
           newValue = TextEditingValue(
             text: _code.visibleText,
             selection: _code.hiddenRanges.cutSelection(selectionSnapshot),
```

Behaviour identical to the three-arm shape; full suite still green.

## Verification

See `tdd/verification.md`.
