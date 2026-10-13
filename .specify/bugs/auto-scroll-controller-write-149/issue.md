# Bug Issue: Auto-scroll does not follow the caret while entering lines one by one (upstream #316)

- **Slug**: auto-scroll-controller-write-149
- **Fetched**: 2026-10-13
- **Issue**: 149
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/149
- **State**: open
- **Severity**: low
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug, severity:low

## Body

The editor does not auto-scroll while code is entered line by line: the caret
walks off the bottom of the viewport and the user has to scroll by hand to find
it again.

Upstream body verbatim:

```
when we enters a code line by line on the same screen auto scroll not working it goes lines down for scroll we need scroll manually.
```

## Comments

None.

## Related

- #42 — the same upstream issue filed earlier, closed by `auto-scroll-caret`
  (the `ConstrainedBox(maxHeight)` bound that gives the field a viewport to
  scroll in). That fix made **typing** scroll the caret into view; #149 is the
  path it did not cover.
