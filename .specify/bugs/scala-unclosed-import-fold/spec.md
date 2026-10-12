# Bug Spec: scala-unclosed-import-fold

Derived from `./assessment.md` for the TDD loop: the required (fixed) behaviour
is the acceptance criteria; the assessment's reproduction is the failing-test
scenario.

## What is broken (regression from `c70a5ae`, PR #135)

An unclosed Scala selective-import brace — `import users.{` whose `}` never
arrives — leaves the parser holding an absorbed pair with no unwind path. The
current code empties the depth counter on the terminator line but drops the
record of what was open, so:

1. the block that opens on the terminator line (the `class` after the import)
   is still absorbed and never folds;
2. the leftover closing brace is reported as unmatched at the **end** line
   instead of the **opening** line, so the gutter issue is drawn on the wrong
   line.

## Required behaviour (acceptance criteria)

- [ ] **AC1 — the block below an abandoned import folds.** For

      ```scala
      import users.{
        User

      class MyClass {
        def method() = {
          body
        }
      }
      ```

      the parser produces `braces(3..7)` **and** `braces(4..6)` — exactly what
      merge-base `25e4c1a` (pre-#135) produces.

- [ ] **AC2 — the diagnostic points at the opening line.** The same sample
      produces `invalid: [InvalidFoldableBlock(startLine: 0, type: braces)]`,
      again matching merge-base. Not `endLine: 7`.

- [ ] **AC3 — the pool's own fixture moves with the fix.** The Scala test
      `An unclosed import brace stops absorbing after a keyword line` (added by
      `c70a5ae`, currently expecting `[braces(2..4)]` + `invalid:[endLine:5]`)
      is re-pinned to the restored behaviour for its own sample.

- [ ] **AC4 — JS keeps its already-correct behaviour.** An unclosed JS import
      still yields `braces(3..5)` + `invalid:[startLine:0]` (JS imports carry no
      qualifier, so they are not absorbed at all — pinned as the cross-language
      regression guard).

- [ ] **AC5 — the #117 feature itself is untouched.** A closed Scala selective
      import still folds as one `imports` block, a member list holding its own
      pairs produces no extra block, Go's parenthesized import group keeps its
      own fold, and every other language's folding suite stays green.

- [ ] **AC6 — coverage stays at the 100% gate**, with no new exemption.

## Reproduction (the failing test scenario)

```dart
test('<name>', () {
  const code = '''
import users.{
  User

class MyClass {
  def method() = {
    body
  }
}''';
  _Tester.parseAndCheck(
    mode: scala,
    code: code,
    expected: const [
      FB(firstLine: 3, lastLine: 7, type: FBT.braces),
      FB(firstLine: 4, lastLine: 6, type: FBT.braces),
    ],
    invalid: [InvalidFoldableBlock(startLine: 0, type: FBT.braces)],
  );
});
```

Red on the current tree: `expected [braces(3..7), braces(4..6)]` vs
`actual [braces(4..6)]`, and `invalid` reports `endLine: 7` instead of
`startLine: 0`.

## Out of scope

- Changing which pairs are absorbed (the `_foundImportQualifier` gate from
  `c70a5ae` stays).
- Any behaviour for closed imports, which already works.
