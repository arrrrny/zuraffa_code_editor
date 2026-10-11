# Bug Spec: a single tap commits an autocomplete suggestion, and the popup fits the window

**Slug**: `autocomplete-double-tap-popup-84`
**Branch**: `bug/autocomplete-double-tap-popup-84`
**Source**: assessment `./assessment.md` from issue
[#84](https://github.com/arrrrny/zuraffa_code_editor/issues/84) (upstream
`akvelon/flutter-code-editor#205`)

## User Story 1 — A single tap selects a suggestion (Priority: P1)

A developer on a phone types a prefix, taps the completion they want, and the
word is inserted. They do not tap a second time, and they do not wait for a
double-tap timeout to expire before the first tap registers.

**Why this priority**: this is the reported symptom and the entire
touch-audience experience of autocompletion.

**Acceptance Scenarios**:

1. **Given** the completion popup is showing, **When** the user taps a row once,
   **Then** the word replaces the prefix, the popup hides, and the editor takes
   focus.
2. **Given** the popup is showing, **When** the user taps a row once, **Then**
   the commit is observable without waiting for a double-tap timeout.
3. **Given** the popup is showing on a device with a keyboard, **When** the user
   presses Enter, **Then** the word is committed exactly as before.

---

## User Story 2 — The popup stays inside the window (Priority: P1)

A developer with the caret near the right edge of a narrow editor, or near the
bottom edge of the window, opens the popup and reads every row of it. No part of
it is outside the window.

**Why this priority**: a clipped popup cannot be acted on, and it is the second
half of the same report.

**Acceptance Scenarios**:

1. **Given** a caret near the right edge of an editor narrower than the popup's
   width plus the caret offset, **When** the popup opens, **Then** its left edge
   is at or inside the window's left edge, and its right edge at or inside the
   window's right edge.
2. **Given** a caret near the bottom edge of the window, **When** the popup
   opens, **Then** the popup is flipped above the caret when there is no room
   below, and it is not flipped when there is room below — decided by the
   height the suggestions actually need, not by the popup's maximum height.
3. **Given** the popup is showing on a desktop layout where the editor occupies
   part of the window, **When** it opens, **Then** it is placed against the
   window's bounds, not the editor's.

---

## User Story 3 — Keyboard and hover behaviour is unchanged (Priority: P2)

A developer navigates the popup with the arrow keys and commits with Enter. The
tap change does not disturb that path, and the desktop hover highlight stays.

**Why this priority**: the tap fix must not trade a touch regression for a
keyboard one.

**Acceptance Scenarios**:

1. **Given** the popup is showing, **When** the user presses the down arrow
   twice and then Enter, **Then** the third row is committed.

---

## Functional Requirements

- **FR-001**: A single tap on a completion row MUST commit the selected word.
- **FR-002**: A single tap MUST commit without waiting for the double-tap
  timeout to expire.
- **FR-003**: Committing MUST hide the popup and return focus to the editor,
  exactly as the Enter path does.
- **FR-004**: The popup's horizontal position MUST be clamped to the window,
  never derived by subtracting an unexplained constant from the editor's width.
- **FR-005**: The vertical flip MUST be decided by the height the suggestions
  actually need, capped at the popup's maximum height.
- **FR-006**: The popup's placement MUST be measured against the window, not
  against the editor's own render box.
- **FR-007**: The change MUST NOT alter the package's public surface —
  `lib/zuraffa_code_editor.dart` does not export `src/wip/`, and it must stay
  that way.

## Success Criteria

- **SC-001**: A single tap on a row commits the word, in a test driven through
  `wt.tap` (the touch path), in one tap.
- **SC-002**: The commit is observable after a short pump, with no
  `kDoubleTapTimeout` wait.
- **SC-003**: A popup in an editor narrower than its own width plus the caret
  offset is positioned entirely inside the window.
- **SC-004**: A caret near the bottom of the window produces a flipped popup
  that is entirely inside the window, and a caret with room below produces an
  unflipped one.
- **SC-005**: Arrow navigation and Enter commit behave exactly as before.

## Edge Cases

- A very short editor (shorter than the popup's maximum height): today the flip
  is refused outright and the popup runs past the bottom edge. After the fix it
  must still be placed inside the window.
- A single suggestion: the needed height is one row, so no flip should be
  triggered by the constant.
- A popup wider than the window: the clamp must not produce a negative width.
- The field resolves the window and hands it to the popup (`editingWindowSize`
  is the window, not the editor's render box), so the popup reads no
  `MediaQuery` itself.
