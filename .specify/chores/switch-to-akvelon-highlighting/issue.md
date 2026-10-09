# Chore Issue: Switch to the Akvelon highlighting package

- **Slug**: switch-to-akvelon-highlighting
- **Fetched**: 2026-10-09
- **Issue**: 37
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/37
- **State**: open
- **Author**: arrrrny
- **Labels**: chore

## Body

Upstream body verbatim:

```
(No description was provided on the upstream issue.)
```

Synced from upstream `akvelon/flutter-code-editor#230 — "Switch to the Akvelon highlighting package"`.

## Why it matters

Upstream had its own highlighting package (`flutter_highlight`) but the
editor consumes the lower-level `highlight` package. Consolidating on the
Akvelon fork (or the other way around) removes a maintenance seam; the decision
should be made deliberately, with the API delta written down.

## Acceptance criteria

- [ ] Decide the target package and record why
- [ ] If switching: migrate imports, keep behavior, update tests and README
- [ ] If not switching: document the decision and close

## Comments

None.
