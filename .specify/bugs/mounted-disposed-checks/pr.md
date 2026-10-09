# Bug PR: Guarded lifecycle continuations (mounted-disposed-checks)

- **Slug**: mounted-disposed-checks
- **Opened**: 2026-10-09
- **PR**: 8
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/pull/8
- **Branch**: fix/mounted-disposed-checks → master
- **Issue**: 4

Guards both remaining dispose-sensitive continuations found by the audit of
upstream akvelon/flutter-code-editor#299, each pinned by a dispose-case +
happy-path regression test. Verification report: ./test.md
(result `partial` — symptom 1 verified, symptom 2 hardened but not
reproducible on Flutter 3.47.5).
