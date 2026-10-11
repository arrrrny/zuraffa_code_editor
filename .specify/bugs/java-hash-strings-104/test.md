# Test: java-hash-strings-104

## Full suite

`flutter test` on `bug/java-hash-strings-104` @ `0efb5fc`:

```
04:09 +766: All tests passed!
```

**766 tests, 0 failures** (758 on master + 8 new).

## New tests

`test/src/highlight/java_language_test.dart` (6 through `CodeController`,
2 on the seam):

| Test | Result |
|---|---|
| `classifies the document around a # and a triple-quoted string` | green (red without the fix) |
| `keeps every character of the source` | green (round-trip holds either way) |
| `a # outside a string or a comment keeps the rest of the document highlighted` | green (red without the fix) |
| `a # inside a string or a comment is not markup` | green (never bails) |
| `an unterminated triple-quoted string leaves the document highlighted up to it` | green (red without the fix) |
| `a document without the defects highlights exactly as the shipped mode does` | green (red without the fix) |
| `hands back the java mode it was given a repaired copy for` | green (unit seam) |
| `leaves every other mode exactly as it was supplied` | green (unit seam) |

## Red check

With only the registration line reverted (`git stash push
lib/src/code_field/code_controller.dart`):

```
Expected: [ (keyword, package), (keyword, import), (keyword, public),
            (class, class A ), (keyword, class), (title, A),
            (keyword, private), (string, """…""" ) ]
  Actual: []
  Which: at location [0] is [] which shorter than expected
```

Three tests fail this way. `Actual: []` is the filed defect verbatim — the whole
document came back as one unclassified node, so nothing classified at all.

## Static checks

- `dart analyze` — `No issues found!`
- `dart format --output=none --set-exit-if-changed lib test` — clean
- README — a `#### Java: # and triple-quoted strings` subsection under Syntax
  Highlighting, describing the repair and what it deliberately leaves alone

## Coverage gate

```
zuraffa_code_editor line coverage: 100.00% (3371/3371 lines over 106 files)
excluded individual lines (see EXEMPT_LINES): 13
Coverage gate: 100.00% >= 100.00% — OK
```

The repaired mode adds no uncovered line: `mode_patches.dart` is three
top-level initialisers and one conditional, all covered by the `modeToRegister`
tests.

## One harness artifact worth recording

The full-suite **coverage** run reported one failure that the plain
`flutter test` run of the same tree did not, and that the isolated
`flutter test --coverage test/src/code_field/no_language_keystroke_test.dart`
does not reproduce either:

```
no_language_keystroke_test.dart: No language selected does not make a
keystroke expensive [E]
  Expected: a value less than <100000>
    Actual: <115524>
```

`no-language keystroke pin: 4800 lines` measured 115 ms against a 100 ms
bound. The same file in isolation with the same instrumentation measures
58.5 ms, and the whole suite without instrumentation passed. The test's own
comment warns about this — "building and dropping a large document leaves the
debug heap churned enough that a measurement taken after a bigger one reads up
to 2.5x slower than the same size measured first — an artifact of the harness,
not of the editor" — and the numbers in the failing run bear that out across
the board: `highlight.parse java` 1003 ms against 317 ms in isolation, i.e.
>3x on both paths at once, so no path-specific regression.

This is pre-existing flakiness under `--coverage`, present on master with the
same harness, and not something this change touched: the ratio assertions in
that test, which are the ones that detect a change in the no-language path,
passed (`noLanguageKeystroke / javaKeystroke` measured 0.101 against a 0.6
bound, the same ~9x separation the file documents).
