# TDD test list: codeline-copywith-drops-indent

Derived from `spec.md`. Order is red-first: the two pinning the defect come
before the controls.

| # | Test | Target | Red on master? |
|---|------|--------|----------------|
| 1 | `copyWith` replaces only the given fields, keeping the range as-is | requirement 4 | no (guard) |
| 2 | `copyWith` recalculates the indent when text changes | requirement 3 | no (guard) |
| 3 | `copyWith` keeps the existing indent when text is not replaced | requirement 1 | **yes** |
| 4 | `copyWith` replaces isReadOnly | requirement 4 | no (guard) |
| 5 | a read-only line inside a named section keeps its indent | requirement 5 | **yes** |
| 6 | a control: indentation of an unmarked code | requirement 6 | no (control) |

Requirements 2 (`textRange` only) is covered by test 1, which passes `textRange`
implicitly and asserts it survives; test 3 covers the "no `text`" path that
test 1 does not.
