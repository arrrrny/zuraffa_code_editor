# Test list: autocomplete-popup-transparency

| # | Test | Type |
|---|---|---|
| 1 | a decoration leaves the popup background opaque — `decoration:` set, popup open → the popup `Container`'s `BoxDecoration.color` is non-null with alpha 1.0 | widget (red on master: `Expected: not null` / `Actual: <null>`) |
| 2 | an explicit `autocompleteBackground` wins over both the decoration path and the theme fallback | widget (red without the precedence: `Expected: Color(0xff123456)` / `Actual: Color(0x21212121)`) |
| 3 | no decoration → the popup background still equals the editor background | widget (regression guard, passes on master) |

The defect lives in the overlay entry built outside the field's subtree,
so only a widget test can observe it; no unit seam was added.
