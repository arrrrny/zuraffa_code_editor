# Bug Issue: Sluggish performance past a few hundred rows

- **Slug**: performance-hundred-rows
- **Fetched**: 2026-10-09
- **Issue**: 39
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/39
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
Performance issues can occur if the number of rows exceeds a few hundred
，Very sluggish
```

Synced from upstream `akvelon/flutter-code-editor#255 — "Performance issues can occur if the number of rows exceeds a few hundred"`.

## Why it matters

Same family as fork issues #18 (large files render blank) and #22 (lazy
loading): cost grows superlinearly with row count and typing becomes
sluggish. Filed separately because the symptom (sluggishness, not blank
lines) and the repro threshold (a few hundred rows) are distinct.

## Acceptance criteria

- [ ] A benchmark captures input/edit latency vs row count
- [ ] The growth is sub-linear for the sizes users report (a few hundred to a few thousand rows)
- [ ] At least one measurement-backed optimization lands

## Comments

None.
