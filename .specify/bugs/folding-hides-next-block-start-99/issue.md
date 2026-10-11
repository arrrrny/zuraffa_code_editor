# Bug Issue: A foldable block ending where another one starts hides the second block's start

- **Slug**: folding-hides-next-block-start-99
- **Fetched**: 2026-10-11
- **Issue**: 99
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/99
- **State**: open
- **Severity**: medium
- **Author**: (triage automation)
- **Labels**: bug, severity:medium

## Body

Upstream #213 on `akvelon/flutter-code-editor`.

**What is wrong / missing**

Folding a block whose closing line is the opening line of the next block
hides the next block's first line too. Block-adjacency logic in the
hidden-range calculation.

**Where it lives**

`lib/src/folding/foldable_block.dart`

**Classification**

- label: `bug`
- severity: `medium`
- backlog rank: 2

## Comments

None.
