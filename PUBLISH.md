# Publish Configuration for `zuraffa_code_editor`

<!-- Ceremony adopted from the zuraffa_permissions / zikzak_inappwebview publish flow. -->

## Package Manager

- **Type**: `pub.dev`
- **Packages**: `zuraffa_code_editor` — a single package published from the repository root.
- **Public**: yes

## Scripts

- **Pre-publish**: `./scripts/prepare_for_publish.sh <version>` — creates a `publish-<version>` branch, bumps the package version, verifies the CHANGELOG entry exists, commits
- **Publish**: `./scripts/publish.sh` — `flutter pub publish --dry-run`, then the real publish (needs flutter/dart on PATH and pub.dev credentials)
- **Post-publish**: `./scripts/push_to_master.sh -f` — merges the publish branch into `master`, tags, pushes, deletes the branch

## Workflow

1. Write the release notes as a `## <version>` entry at the TOP of `CHANGELOG.md`
2. `./scripts/prepare_for_publish.sh <version>`
3. `git push -u origin publish-<version>`
4. `./scripts/publish.sh`
5. Wait for pub.dev to index the new version
6. `./scripts/push_to_master.sh -f`

## Versioning

This is a fork of `flutter_code_editor` 0.3.5, but it publishes on its own
version line starting at `0.1.0`. The upstream base version is recorded in
`CHANGELOG.md` and `README.md` so the mapping stays traceable.

## Local development

There are no `dependency_overrides`; the package resolves its dependencies
from pub.dev like any other package.
