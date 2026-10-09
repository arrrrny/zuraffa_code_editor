# Bug Issue: Folding a block hides the start of the following block

- **Slug**: folding-hides-next-block-start
- **Fetched**: 2026-10-09
- **Issue**: 25
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/25
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
Initial code:
<img width="517" alt="Screen Shot 2023-04-13 at 12 21 15" src="https://user-images.githubusercontent.com/79095619/231671397-16cbb84c-6845-43e2-acff-be59c67cd2bb.png">

When folding at 3, the start of the next foldable block also becomes hidden:
<img width="505" alt="Screen Shot 2023-04-13 at 12 21 24" src="https://user-images.githubusercontent.com/79095619/231671403-255ed3c4-6bde-4b3f-99e7-80b0bc566433.png">
```

Synced from upstream `akvelon/flutter-code-editor#213 — "Foldable block doesn't fold correctly when there is another foldable block at the end of the first"`.

## Why it matters

Folding one block must hide exactly its lines. Hiding the start of the next
block destroys code the user asked to keep visible.

## Acceptance criteria

- [ ] Root cause identified in the folding logic (`foldable_block.dart` / hidden ranges) when two blocks are adjacent
- [ ] Folding block A hides only A's lines, including A's trailing block-start line
- [ ] A regression test pins the hidden-range set for adjacent blocks

## Comments

None.
