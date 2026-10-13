# Test list: gutter-textstyle-alignment-150

File: `test/src/gutter/gutter_textstyle_audit_test.dart`.
Harness: `test/src/gutter/gutter_alignment_harness.dart`, which is already
parameterised by `gutterStyle` — the #43 alignment tests never passed one.

| # | Test | Type |
|---|---|---|
| 1 | a differing gutter `fontSize` cannot move the gutter off the grid | widget |
| 2 | a differing gutter `fontFamily` cannot move the gutter off the grid | widget |
| 3 | a differing gutter `height` cannot move the gutter off the grid | widget |
| 4 | all three metrics at once cannot move the gutter off the grid | widget |
| 5 | the same holds under Material 3 | widget |
| 6 | colour, weight, style and tracking stay overridable | widget |
| 7 | an omitted gutter style takes the code colour at half alpha | widget |

Tests 1-3 additionally assert the *resolved* style directly, so a failure says
which property leaked through rather than only "the gutter drifted". They are
siblings of the `gutter_alignment_test.dart` and
`gutter_alignment_material3_test.dart` invariants (gutter starts on the text's
top edge, every row exactly one rendered code line tall) and run under the same
`expectEditorLineHeightSet` guard, so their detection power cannot silently
disappear.

## Mutation check

The behaviour these tests pin already existed, so red-green discipline is the
wrong tool: every test is green on the unmodified tree. To prove they are not
vacuous, each of the three forced properties was removed from
`_buildGutter`'s `copyWith` in turn and the suite re-run.

| mutant | result |
|---|---|
| `fontSize: lineNumberSize` removed | 6 tests fail |
| `fontFamily: textStyle.fontFamily` removed | 2 tests fail |
| `height: textStyle.height` removed | 2 tests fail |

All three killed, source restored, suite green again.

## Notes

- No test touches `CodeField` layout beyond what the harness already sets up, so
  nothing here needs a new fake or a `@visibleForTesting` seam.
- The resolved gutter style is read through
  `GutterWidget.style.textStyle`, which is the same object the gutter renders
  with — no re-measurement.

