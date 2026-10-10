# Test list: gutter-alignment (layer 2)

| # | Test | Type |
|---|---|---|
| 1 | `GutterStyle().padding` / `GutterStyle.none.padding` default to zero | unit (red: compile error, field missing) |
| 2 | `copyWith` keeps the current padding and accepts an override | unit |
| 3 | padding shifts the gutter column by exactly the insets and keeps row pitch | widget (red without the `gutter.dart` wrapper: `Expected: <4> Actual: <0.0>`) |
