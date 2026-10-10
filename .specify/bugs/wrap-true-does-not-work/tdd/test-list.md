# Test list: wrap-true-does-not-work

| # | Test | Type |
|---|---|---|
| 1 | `wrap: true` reflows a 200-char line into a 200px viewport — the field's width stays ≤ 200 and its height grows past one row | widget (red on master: `Actual: <2903.0>`) |
| 2 | `wrap: false` still lays the line out horizontally — field wider than the viewport, one visual row | widget (regression pin, passes on master) |
| 3 | the gutter scrolls in lockstep with wrapped code — the two scroll extents are equal, and a jump in either is mirrored in the other | widget (red on master: the gutter's extent is far shorter than the code's) |
| 4 | unwrapped lines keep the extents equal — the wrapped-row measurement does not disturb the default layout | widget (regression pin, passes on master) |

The defect is layout behaviour in the widget tree, only observable through
real rendering; no unit-test seam was added.
