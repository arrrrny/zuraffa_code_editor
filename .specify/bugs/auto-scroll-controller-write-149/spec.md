# Spec: auto-scroll-controller-write-149

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/149
(upstream akvelon/flutter-code-editor#316, still open there).

## Requirement

A value change written through `CodeController` moves the caret, and the caret
must be revealed exactly as a keystroke reveals it. Writing the document line
by line and keeping the selection on the line just written keeps the caret in
view; the gutter follows, because the code scroll views are linked.

## Acceptance

- After 40 programmatic line-by-line writes with the caret on the last line,
  the `Scrollable` inside the `EditableText` has `pixels > 0`.
- The gutter's offset equals the editor's after the same writes.
- A caret the host moves back toward the top of the document is revealed
  upward.
- A caret already inside the band moves the offset by nothing.
- A write made while the field is unfocused does not scroll.
- A write that names no selection leaves the framework's repair (caret at the
  end of the written text) and reveals it.
- A field whose host disabled scrolling is not scrolled by the reveal.
- A reveal scheduled for a field the host unmounts in the same frame is
  dropped, with no exception.
- No regression: full suite green, `dart analyze --fatal-infos` clean, format
  clean, coverage gate at 100%.

## Non-goals

- Changing the typing path's reveal: the framework owns it and it works.
- Horizontal scrolling of the field as a whole: out of scope, and #91 already
  gave the field a horizontal scrollbar.
- Animated reveals: the framework animates its own path; a controller write is
  a host's deliberate reposition, and lands where it was asked to.
