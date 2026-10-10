# Chore Assessment: List web as a supported platform

- **Slug**: list-web-as-supported-platform
- **Created**: 2026-10-10
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/23
- **Verdict**: in scope
- **Size**: medium

**Issue:** [arrrrny/zuraffa_code_editor#23](https://github.com/arrrrny/zuraffa_code_editor/issues/23) — synced from upstream `akvelon/flutter-code-editor#208`.
**Label:** `chore`

The issue asks for two things, in order:

> *"The first thing is to find why it cannot be automatically detected. Write this reason here. Then we will decide if we fix that reason or explicitly list web as a supported platform."*

This assessment answers the first half — the reason — with a reproduced causal chain, so the decision in the second half can be made on evidence rather than on a guess.

## The observation

pub.dev lists `android, ios, linux, macos, windows` for this package and **not `web`** — the same five tags as the upstream `flutter_code_editor` it was forked from. The fork's README has no platform list of its own, so pub.dev's tags are the only platform claim being made.

Reproduced locally with the same tool pub.dev uses, so the cause is not an artifact of the pub.dev environment:

```bash
dart pub global activate pana
pana --source path . --json | grep -o 'platform:[a-z]*'
# platform:android platform:ios platform:linux platform:macos platform:windows
```

## Why web is not detected

`pubspec.yaml` declares no `platforms:` key, so pub.dev derives the tags from the dependency graph. Every direct dependency was checked:

| dependency | web |
|---|---|
| `autotrie` | **no** |
| `characters`, `charcode`, `collection`, `equatable`, `http`, `highlight`, `flutter_highlight`, `linked_scroll_controller`, `meta`, `mocktail`, `scrollable_positioned_list`, `tuple`, `url_launcher` | yes |

A single dependency is missing web: **`autotrie`**.

Chasing it down reproduces the blocker exactly. `zuraffa_code_editor` imports `package:autotrie/autotrie.dart` from `lib/src/autocomplete/autocompleter.dart:1`, and that entry point is a one-line re-export:

```dart
export 'src/autotrie_base.dart';
```

and `src/autotrie_base.dart:1` is:

```dart
import 'dart:io';
```

`dart:io` has no web implementation, so a web build of anything that reaches the autocompleter fails to compile. That is the reason web cannot be automatically detected.

`autotrie` has been dormant since 2021-05-28 (latest and only viable release is 2.0.0, 4 open issues), so no version bump closes the gap.

## Where the import actually matters

The `dart:io` import is confined to two methods of `autotrie`'s `AutoComplete`:

```dart
AutoComplete.fromFile({required File file, required SortEngine engine})
Future<void> persist(File file) async
```

Both are file-persistence helpers, and **neither is used here**. The only `autotrie` surface this package touches is the in-memory constructor and two methods:

```dart
AutoComplete(engine: SortEngine.entriesOnly())   // lib/src/autocomplete/autocompleter.dart:9,10,99
.clearEntries()                                   // :27, :119, :138
```

The in-memory path is pure Dart with no `hive` involvement — `hive` is only reached through `fromFile`/`persist`, which is why `hive` itself still reports `platform:web` while `autotrie` does not.

## Options

### (a) Fix the reason — replace `autotrie` with an in-house autocompletion engine

Port the ~100 lines of `AutoComplete` plus `_TrieSearchTree` and `SortEngine.entriesOnly` into `lib/src/autocomplete/`, dropping the two `File`-taking methods. The dependency goes away, web becomes genuinely supported, and the package stops depending on a 2021-dormant package — the same fork-and-revive pattern as `zikzak_inappwebview`.

Cost: the port must reproduce `autotrie`'s matching and ranking exactly, or autocompletion behaviour changes. The existing suite is the contract — `flutter test` is 605 tests, and any behavioural drift shows up there.

### (b) Explicitly list web

Add a `platforms:` key to `pubspec.yaml` declaring all six platforms.

This would be a **false claim**: the package would still fail to compile on web, because `dart:io` would still be in the graph through `autotrie`. It is only honest after (a).

## Recommendation

Do (a). The port is small, the observable surface in use is narrower still, and the alternative declares support for a platform the package cannot build on. Do not close this issue on (b) alone.
