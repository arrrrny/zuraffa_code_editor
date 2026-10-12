# Plan: Insert toggles insert/overtype mode

**Spec:** ./spec.md
**Issue:** [arrrrny/zuraffa_code_editor#83](https://github.com/arrrrny/zuraffa_code_editor/issues/83)
**Label:** `spec`

## Design

The toggle is a shortcut and the replacement is a transform in the `value`
setter. Neither touches a hot path that is not already running.

### 1. `lib/src/code_field/actions/overtype.dart`

A copy of `actions/enter_key.dart` with one method call in the middle:

```dart
class ToggleOvertypeIntent extends Intent {
  const ToggleOvertypeIntent();
}

class ToggleOvertypeAction extends Action<ToggleOvertypeIntent> {
  final CodeController controller;
  ToggleOvertypeAction({required this.controller});

  @override
  Object? invoke(ToggleOvertypeIntent intent) {
    controller.toggleOvertypeMode();
    return null;
  }
}
```

### 2. `CodeController` carries the flag

```dart
bool isOvertypeMode = false;

void toggleOvertypeMode() {
  isOvertypeMode = !isOvertypeMode;
}
```

A public field, not a getter/setter pair: `dart analyze --fatal-infos` flags the
wrapper as `unnecessary_getters_setters`, and a field is the same API to the
host. `ToggleOvertypeIntent: ToggleOvertypeAction(controller: this)` joins the
existing `actions` map.

### 3. The transform runs after the modifier dispatch

```dart
if (_isTabReplacementEnabled) {
  newValue = newValue.tabsToSpaces(params.tabSpaces);
}

if (isOvertypeMode && !readOnly) {
  newValue = _overtypedValue(newValue) ?? newValue;
}
```

```dart
TextEditingValue? _overtypedValue(TextEditingValue newValue) {
  final loc = _insertedLoc(text, newValue.text);
  if (loc == null || loc >= text.length) {
    return null;
  }

  final newSelection = newValue.selection;
  if (!newSelection.isCollapsed || newSelection.start != loc + 1) {
    return null;
  }

  return TextEditingValue(
    text: text.replaceRange(loc, loc + 1, newValue.text[loc]),
    selection: TextSelection.collapsed(offset: loc + 1),
  );
}
```

Two independent predicates gate it, and each is a branch that needs its own
test:

- `_insertedLoc` — the text grew by exactly one and the caret the platform is
  editing from is collapsed, which is what `_insertedLoc` already states for the
  modifier dispatch. It rules out deletions, pastes and multi-character edits in
  one comparison.
- `loc < text.length` — there is a character after the caret to overwrite.
- `newValue.selection` is collapsed one past the insertion — the platform
  applied the character *at the caret*, not somewhere else.

Placing the call after the modifier dispatch is what makes an auto-paired
keystroke keep its pair: once the modifier has run, `newValue.text` is two
characters longer and `_insertedLoc` already returns null.

## Order of work

1. `test/src/code_field/insert_overtype_test.dart` — red, because
   `CodeController` has no `isOvertypeMode` and the file does not compile.
2. `isOvertypeMode`, `toggleOvertypeMode`, the action and the binding.
3. `_overtypedValue` and its call site. Tests 7–9, 11 and 14 go green.
4. Real-key tests, Ctrl-Insert, composing, read-only. Tests 2–5.
5. CHANGELOG entry, Spec-Kit artifacts, coverage gate.

## Risks

- **`readOnly` must be guarded here.** `_getEditResultNotBreakingReadOnly`
  refuses the edit afterwards, but by then `_overtypedValue` has already
  rewritten `newValue` — and the `value` setter returns *before* assigning
  `super.value`, so no state leaks even so. The guard is what makes the intent
  readable; test 14 pins it.
- **A real keystroke on a folded block** is the same transform under
  `recoverSelection` / `cutSelection` that every other edit takes, because the
  transform happens before those run. Test 9 pins the folded body's length.
- **The binding must not steal modified Insert.** A no-modifier
  `SingleActivator` requires no modifiers pressed, so Ctrl+Insert and Shift+Insert
  keep their framework bindings; test 4 pins it.
- **Focus.** `pumpController` requests focus without a following pump, so the
  first key event of a test lands on an unfocused field and reaches no shortcut
  map at all. Every real-key test pumps once first — on pain of a test that
  passes for the wrong reason.
