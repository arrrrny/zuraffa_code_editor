# Bug Issue: Unclosed Scala import brace swallows the class block below it

- **Slug**: scala-unclosed-import-fold
- **Reported**: 2026-10-12
- **Issue**: 137
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/137
- **Severity**: medium

An unclosed Scala selective-import brace stops the block below it from folding
and reports the unmatched brace at the closing line instead of the opening line.
