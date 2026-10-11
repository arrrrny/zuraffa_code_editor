# Bug Issue: Autocomplete needs a double tap on mobile and the popup is cut off

- **Slug**: autocomplete-double-tap-popup-84
- **Fetched**: 2026-10-11T06:08:33Z
- **Issue**: 84
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/84
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug, severity:high

## Body

## What was asked

On mobile the autocomplete dropdown needs a double tap to select an item,
and the dropdown is cut off. The reporter also asks for a custom autocomplete
builder as a way out.

Synced from upstream flutter-code-editor:
- https://github.com/akvelon/flutter-code-editor/issues/205 — "[Bug] Editor on mobile autocomplete needs double tap to select and autocomplete gets cut off"

Upstream body verbatim (excerpt):
```
Editor on mobile autocomplete needs double click to select an item from the dropdown. Also the dropdown gets cutoff. Would be nice to have a custom autocomplete builder option. [includes a simulator screenshot showing the cutoff]
```

## Why it matters

A first tap that lands on nothing makes autocomplete feel broken on touch, which
is the majority of the widget's audience. The cutoff is the same placement bug
the suggestions refactor (#211) calls out — the box flips on the wrong height.

## Acceptance criteria

- [ ] A single tap selects an autocomplete suggestion on touch devices
- [ ] The popup is not clipped by the viewport edge (flips/positions on the height actually needed)
- [ ] Regression tests for both, driven by the touch path rather than the mouse path
- [ ] Desktop behaviour is unchanged

## Triage

- **Label:** bug
- **Severity:** high
- **Backlog rank:** /tmp/triage/4.md0
- **Assess verdict (filled in later):** pending


## Comments

None.
