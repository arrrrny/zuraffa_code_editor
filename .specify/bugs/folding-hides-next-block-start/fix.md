# Fix: folding a block no longer hides the following block's start

Status: **applied** — branch `bug/folding-hides-next-block-start`, base master
`a7f148c`.
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/folding/foldable_block.dart` | `joinIntersecting` now joins only blocks that **cross** (`ancestor.lastLine > bubble.firstLine && ancestor.lastLine < bubble.lastLine`) or that **share a first line** or are duplicates. Blocks that merely touch stay separate, so `factorial` `2..8` and `main` `8..11` are two foldable blocks rather than one `2..11`. |
| `lib/src/code/code.dart` | `foldableBlockToHiddenRange` ends the hidden range at `lastLine.textRange.start - 1` when the block's last line is a closing line **and** another foldable block starts on that line. The closer then keeps a row of its own, and with it its line number and fold toggle. |
| `test/src/folding/folded_block_keeps_next_block_start_test.dart` | **new** — 6 tests using the issue's exact reproduction: the blocks stay separate, the following block's start stays visible (with its row and its toggle), the gutter and the editor agree on the row count, the following block folds on its own, and folding the outer block over the inner one round-trips losslessly. |

## Rationale for the narrow guard

The default folded layout glues the closer onto the opener — `parsers: [`
folds to `parsers: [  ],` — and that is the behaviour the whole suite encodes.
Making every closer keep its own row would be a far wider user-visible change
than issue #25 asks for. So the new row is produced only when the closing line
is also the opening line of the next foldable block, which is precisely the
`}void main(){` shape the issue reports.

## Verification

- `flutter test test/src/folding/` — 55/55 green.
- `flutter test` — 507 tests, all passing.
- `dart analyze` — No issues found.
- `dart format lib test` — clean (0 changed).

## Coverage note

No new measured-coverage claim. The gate is a ratchet; this PR adds no
deliberate coverage claim of its own, and the new test file only exercises
code that was already measured.
