# Assessment — "Switch to the Akvelon highlighting package" (#37)

**Issue:** [arrrrny/zuraffa_code_editor#37](https://github.com/arrrrny/zuraffa_code_editor/issues/37) — synced from upstream `akvelon/flutter-code-editor#230`.
**Label:** `chore`

## What the issue asks

The upstream ticket is a one-liner — "Switch to the Akvelon highlighting package" — with an empty body and one comment:

> *"What's the status of this? The highlighting package is almost unusable from the bugs."* — porterehunley, 2023-09-21

So the ask is: `zuraffa_code_editor` should stop depending on the highlighting package it currently uses, because that package is bug-ridden, and use the one Akvelon (the editor's own maintainer) publishes instead.

## Finding: the target package is real and identified

There **is** an Akvelon highlighting package, and it is the fork of `highlight` that `highlight` itself points at:

- `highlighting` — `highlighting 0.9.0+11.8.0`, published by the **verified publisher `akvelon.com`**, repository [`akvelon/dart-highlighting`](https://github.com/akvelon/dart-highlighting).
- `git-touch/highlight.dart` issue [#47 "We forked this package and have fixed many bugs"](https://github.com/git-touch/highlight.dart/issues/47) is the fork that became it, and #46 "Maintenance status?" is the maintenance question this repo's issue echoes.

The two candidates compared:

| | `highlight` (current) | `highlighting` (Akvelon) |
|---|---|---|
| latest | 0.7.0 | 0.9.0+11.8.0 |
| published | 2021-03-07 | 2023-05-05 |
| repo | `git-touch/highlight.dart` | `akvelon/dart-highlighting` |
| open issues | ~30 | 26 |
| last push | dormant since 2021 | 2023-11-16 |

## Why the migration is not implementable as asked

### 1. It does not resolve

Every version of `highlighting` depends on `equatable: ^2.0.5`, while this package depends on `equatable: ^3.0.0`:

```
Because every version of highlighting depends on equatable ^2.0.5 and
zuraffa_code_editor depends on equatable ^3.0.0, highlighting is forbidden.
```

There are only three releases of `highlighting` (`0.8.0`, `0.8.1+11.7.0`, `0.9.0+11.8.0`) and all three pin `^2.0.5`, so no version choice avoids this.

The `equatable` constraint is stale rather than load-bearing: `highlighting` declares it and never imports it anywhere in `lib/src/` (verified by grep over the extracted archive).

### 2. The only way past it is a dependency downgrade

Setting `equatable: ^2.1.0` here does resolve, and the package's 11 `Equatable` subclasses compile against 2.x — the code uses no 3.x-only API. But that means the switch's real cost is **downgrading a dependency this package exposes to its own consumers**, which is a larger and riskier change than the issue describes and would need its own justification and a dependent-changes audit.

### 3. It would not escape unmaintained code

This is the decisive point. The issue's premise is "the highlighting package is almost unusable from the bugs", and `highlighting` answers it only partially:

- last push 2023-11-16, 26 open issues, no releases since 2023;
- a `dart:js_interop`-era Dart 3 SDK constraint of `>=2.17.0 <3.0.0` in its pubspec, which only resolves here because pub.dev's Dart-3-compatibility tag relaxes it.

Switching would move the dependency from one dormant package to another, so the bug-exposure the reporter complained about would carry over.

## The bugs named in the issue, pinned

Two concrete `highlight` 0.7.0 defects were found while assessing, both reproduced:

1. **Embedded sub-languages declared on `starts` sub-modes never resolve.** `xml`'s mode declares `subLanguage` for `<script>`/`<style>` (and `php` on a plain `contains`), but the `<script`/`<style` tag modes never match them, so script and style bodies stay markup even after registering `javascript` and `css` by name. `<?php ?>` bodies *are* re-parsed. Pinned by `test/src/highlight/html_language_test.dart` (PR #71) and documented in the README.
2. **A language's aliases are not registrations.** `html` is an alias of `xml` and therefore unreachable by name — issue #40, closed by PR #70.

Neither is fixable from this package: both live inside `highlight`'s mode definitions and its registry.

## Recommendation

Do **not** switch. The chore is recorded as **not implementable as stated**, for three reasons that all have to be resolved by an outside change, not by this repo:

- `highlighting` must publish a release whose `equatable` constraint admits 3.x (or drop the unused constraint);
- the `equatable` downgrade cost must be accepted, which is a separate decision with its own blast radius;
- `highlighting` must be maintained again, otherwise the switch relocates the rot instead of removing it.

What would make the issue actionable is a first-party fork of `highlight` — the `zikzak_inappwebview` pattern — published as a `zuraffa`-branded package and consumed here. That is a publishing decision outside this repository and is out of scope for one chore.
