# Quickstart: ellipsis-folded-block

Everything needed to verify this spec, in the order it should be run.

## 1. Worktree and branch

```bash
cd /Users/arrrrny/Developer/zuraffa_115
git log --oneline -1          # must be the plan commit; tree clean
flutter pub get
```

`--concurrency=2` on **every** `flutter test` invocation (and `-j 2` for
`dart test`). `flutter test` ignores `dart_test.yaml` entirely, so the flag is the
only lever — and it must be passed every time. Never raise it on this host.

## 2. Run the regression net first

Before writing anything new, prove the folding and span-tree behaviour is intact.
These are the files whose expectations this spec must not break:

```bash
flutter test --concurrency=2 \
    test/src/code_field/span_builder_test.dart \
    test/src/folding/folded_closing_line_test.dart \
    test/src/folding/folded_block_keeps_next_block_start_test.dart
```

All three must pass **unmodified**. They are the fixtures this feature annotates:
`folded_closing_line_test.dart` pins what a folded line *looks like* as text
(`parsers: [` → `parsers: [  ],`, `:36-50`) and
`folded_block_keeps_next_block_start_test.dart` pins the own-row closer and the
swallowed-nested-fold shapes (`:46-54`, `:121-134`). A RED here after a change to
`span_builder.dart` means the splice is wrong — do not edit the test.

## 3. Seeing the marker

The shortest path to a marker on screen, and the shape the new tests use:

```dart
// test/src/code_field/fold_ellipsis_test.dart
import '../common/create_app.dart';

const config =
    'final config = ScraperConfig(\n'
    '  clientType: HttpClientType.crawler,\n'
    '  parsers: [\n'
    '    ParserConfig(\n'
    '      kind: ParserType.jsonLd,\n'
    '    ),\n'
    '  ],\n'
    ');\n';

testWidgets('shows an ellipsis at the end of the kept line of a folded block',
    (tester) async {
  final controller = CodeController(text: config, language: java);
  addTearDown(controller.dispose);

  controller.foldAt(2); // `  parsers: [`

  await tester.pumpWidget(createApp(controller, FocusNode()));
  await tester.pumpAndSettle();

  // The buffer is unchanged — this is the load-bearing assertion.
  expect(controller.text, '''
final config = ScraperConfig(
  clientType: HttpClientType.crawler,
  parsers: [  ],
);
''');

  // And the tree carries the marker at the end of the kept line.
  final span = controller.lastTextSpan!;
  expect(span.toPlainText(), contains('  parsers: [  ], …'));
});
```

The two files split the work:

- `test/src/code_field/fold_ellipsis_test.dart` — controller and widget level.
  Folds through `controller.foldAt(int)`, asserts `controller.text` and the span
  tree through `controller.lastTextSpan` (`code_controller.dart:1356`), which is
  the same span `EditableText` receives.
- `test/src/code_field/span_builder_test.dart` — span-tree level, one new entry
  in the existing `_examples` map per folded shape. Whole tree asserted, in the
  file's own convention. Build the `Code` directly
  (`span_builder_test.dart:244-256`) and fold it with
  `code.foldedBlock(block)` (`code.dart:588`) before handing it to
  `SpanBuilder`.

Fixtures that already exist and cover the awkward shapes, so nothing has to be
invented:

| Shape | Fixture |
|---|---|
| Glued closer (`parsers: [  ],`) | `folded_closing_line_test.dart:30-50` |
| Closer on its own row (`}void main(){`) | `folded_block_keeps_next_block_start_test.dart:32-54` |
| Nested fold swallowed by an outer one | `folded_block_keeps_next_block_start_test.dart:121-134` |
| Two adjacent folds, both visible | the same source, `foldAt(2)` and `foldAt(8)` |
| Kept line with no trailing newline | a `'// one\n// two\n// three'` comment block folded at line 0 |

## 4. The CI-identical coverage gate

The repo's real gate, byte-for-byte what the pool's CI runs. The helper imports
every file under `lib/` except the `*_web.dart` ones, so coverage is measured
against the whole library rather than the touched module:

```bash
# generate test/coverage_helper_test.dart (one import per lib/**/*.dart except *_web.dart)
flutter test --coverage --concurrency=2
python3 tool/coverage_gate.py --min 100
rm test/coverage_helper_test.dart && rm -rf coverage/
```

Must read `Coverage gate: 100.00% >= 100.00% — OK`. Anything below 100% is a
blocker, not a note.

Two traps:

- **`flutter test` hides failures.** A red bar with no failure text means grep the
  log: `EXCEPTION CAUGHT`, `Expected:`, `Actual:`.
- **A gate run must reflect the final committed tree.** Adding a test file
  mid-run invalidates the number — stop, commit, restart.

`EXEMPT_LINES` in `tool/coverage_gate.py` pins by **line number**, so any
insertion above an exempted line shifts it. Renumber after every insertion, and
add an exemption only with a written reason proving the branch is dead.

## 5. Static gates

```bash
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
```

Note: `analysis_options.yaml` excludes `lib/src/wip` from analysis. Nothing this
spec touches is under `lib/src/wip`, but if a change strays there, say so in the
PR — new `wip` code is unlinted and the reviewer should not have to discover it.

## 6. What must fail before the implementation exists

Per the repo's TDD profile, every test below is written and run RED first. This
is the checklist that proves the tests can actually fail:

| Change | Test that must go RED |
|---|---|
| Remove the splice entirely | `shows an ellipsis at the end of the kept line of a folded block` — the tree has no `' …'` |
| Append the marker to every node on the kept line instead of the terminating one | the span-tree example finds the marker mid-line |
| Hard-code the marker onto line 0 | every folded example except the first |
| Keep the marker after an unfold | `drops the ellipsis when the block is unfolded` |
| Style the marker with the terminating node's style only | `styles the ellipsis with the base style, not the token style` |
| Append the marker to the last node of the walk unconditionally | the own-row-closer case finds a marker on the closer's row |
| Skip the final-line splice | `shows the ellipsis on a kept line that is the last line with no trailing newline` |
| Derive kept lines without discarding the nulls | the nested-fold case finds a second marker that has no row |
| Omit `withFoldEllipsis: matches.isEmpty` in `buildTextSpan` | `a match after a folded line still lands on its own text` — every match following the folded line is sliced off the wrong text |

The single most plausible wrong implementation is appending the marker to the
*last child* of the terminating node's span instead of splicing it in front of
the node's trailing newline run. It looks equivalent, because `node.dart:62-67`
hands the first piece of a split node both a value and children, and those
children render after a value that is itself a newline — so the marker ends up
after the *following* line's text. It passes the shared-row fixture when the
terminating node happens to be a leaf and fails on any document where it is not,
which is why the own-row-closer and final-line tests are load-bearing.

The second most plausible is silencing the marker for the whole search panel by
dropping it from `search_result_highlighted_builder.dart`'s input instead of
suppressing it at the source. That works, but it edits the search builder, which
this spec does not own; the flag on `SpanBuilder` keeps the change local.

## 7. Known host flake

`test/src/code_field/no_language_keystroke_test.dart` asserts an absolute 100 ms
bound calibrated on a machine where the with-language parse measures 80.7–96.
ms. On this host that parse measures ~570 ms, so the test fails under full-suite
load **on master too** — it is environmental, not a regression, and it is
unrelated to this change. Re-run it alone to confirm:

```bash
flutter test --concurrency=2 test/src/code_field/no_language_keystroke_test.dart
```

Do not widen the bound: it is a tripwire for a real regression, and loosening it
weakens it silently. Flag it in the PR body with the master comparison numbers.

## 8. PR

Only after the gate reads 100.00% and both static gates are silent. The PR body
records: what the marker is and where it is spliced, the "painted, not typed"
constraint and the test that enforces it, the terminating-node rule and the two
shapes it distinguishes (glued closer vs own-row closer), the base-style decision,
the IME-composition and no-language bypasses, and the coverage number. Then push
and requeue the pool review with
`/Users/arrrrny/Developer/forklift/tool/requeue_review.dart`. **Do not merge** —
the pool merges.
