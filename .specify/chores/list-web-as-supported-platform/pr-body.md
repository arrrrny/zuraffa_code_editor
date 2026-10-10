## Summary

Fixes the reason web cannot be automatically detected
([#23](https://github.com/arrrrny/zuraffa_code_editor/issues/23)) — the first
half of what the issue asked for — then lists the platform explicitly. Closes
upstream [akvelon/flutter-code-editor#208](https://github.com/akvelon/flutter-code-editor/issues/208).

The reason, reproduced with the same tool pub.dev uses:

```bash
dart pub global run pana --source path . --json | grep -o 'platform:[a-z]*' | sort -u
# android ios linux macos windows          ← no web
```

`pubspec.yaml` declares no `platforms:` key, so pub.dev derives the tags from
the dependency graph, and exactly one direct dependency is missing web:
**`autotrie`**. The chain is one link long:

```
lib/src/autocomplete/autocompleter.dart:1   import 'package:autotrie/autotrie.dart';
package:autotrie/autotrie.dart             export 'src/autotrie_base.dart';
package:autotrie/src/autotrie_base.dart:1  import 'dart:io';
```

`dart:io` has no web implementation, so a web build of anything that reaches the
autocompleter fails to compile. `autotrie` has been dormant since 2021-05-28,
so no version bump closes the gap.

## Changes

| File | Change |
|------|--------|
| `lib/src/autocomplete/auto_complete.dart` | **new** — the in-house engine (`AutoComplete`, `SortEngine`, `SortValue`, `_TrieSearchTree`, `TrieString`, `TrieNode`) |
| `lib/src/autocomplete/autocompleter.dart` | import rewired to `auto_complete.dart` |
| `pubspec.yaml` | `autotrie: ^2.0.0` removed; `platforms:` declaring all six added |
| `test/src/autocomplete/auto_complete_test.dart` | **new** — 36 tests over the ported surface |
| `README.md` | multi-platform sentence states the six platforms and why web is real |
| `CHANGELOG.md` | `Unreleased › Added` entry |
| `.specify/chores/list-web-as-supported-platform/` | `implement.md`, `test-list.md` |

## The port

The `dart:io` is confined to two members of `autotrie`'s `AutoComplete`:

```dart
AutoComplete.fromFile({required File file, required SortEngine engine})
Future<void> persist(File file) async
```

Both are file-persistence helpers and **neither has a caller here** — the only
surface the package touches is the in-memory constructor, `clearEntries` and
`suggest`. So the port carries the in-memory half and drops `fromFile`,
`persist`, `changedSincePersist` and the Hive integration. `hive` was only
reachable through those two methods, so it leaves the graph with `autotrie`:

```
$ flutter pub deps --style=compact | grep -iE 'autotrie|hive'
(nothing)
```

`SortEngine` keeps only the `entriesOnly` constructor the package uses; the
time-based engines scored `SortValue.lastInsert`, which becomes pure
bookkeeping once they are gone, and `msToNow` goes with them.

Two dead constructs were removed rather than ported:

```dart
return base.children == <TrieNode>[];   // fresh literal on every evaluation, so always false
int get msToNow => ...                  // no caller left once the time engines are gone
```

## Two deliberate divergences from `autotrie`

The port is not bug-compatible in two places. `autotrie` is dormant since
2021-05-28 and cannot be fixed upstream; this repository owns the code now.
Neither surface is reachable from `Autocompleter`, which only calls
`clearEntries`, `enterList` and `suggest`, so neither can move the package's
own autocompletion behaviour.

**1. `contains` means "was entered", not "the characters exist".**
`_TrieSearchTree.search` walked the prefix and returned `true` on reaching the
end, never consulting the terminal `hits` — so an engine holding `alpha`
answered `true` for `alph`, and for `alpha` after it had been deleted. It now
returns `base.hits > 0`.

**2. `delete` removes the word it is told to remove.**
`_delete` returned `cur.children.isEmpty` at the terminal node and pruned only
childless, hitless nodes on the way back up. When a longer word shared the
prefix, the end node had a child, so nothing was ever pruned and the terminal
node's `hits` were never cleared — the word stayed suggested forever. Tracing
`delete('alpha')` on an engine holding `alpha` and `alphabet`: every
`shouldDeleteNode` on the way up is `false`, and `alpha` keeps `hits == 1`.

It now clears the hit first and prunes on `next.hits == 0`. Pinned by
"the survivor of a shared-prefix delete is deletable too", which cannot pass
under the old `_delete`.

## Verification

- `pana --source path .` → `android ios linux macos web windows`
- `flutter test` → **All 646 tests pass** (610 on master; +36 engine tests)
- `python3 tool/coverage_gate.py --min 100` → **100.00% (3273/3273 lines over
  104 files)**, `lib/src/autocomplete/auto_complete.dart` at 100.00%)
- `dart analyze --fatal-infos` → No issues found
- `dart format --output=none --set-exit-if-changed .` → no changes
- `flutter pub get` resolves cleanly in the package and in `example/`
