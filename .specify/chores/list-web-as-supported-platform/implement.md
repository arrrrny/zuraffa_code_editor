# Chore Implementation: List web as a supported platform

- **Slug**: list-web-as-supported-platform
- **Implemented**: 2026-10-10
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Option (a) from the assessment: `autotrie` is gone, replaced by an in-house
engine in `lib/src/autocomplete/auto_complete.dart`. `dart:io` leaves the
dependency graph, so `android, ios, linux, macos, windows, web` become the real
platform set rather than a claim. `hive` drops out as a transitive dependency
for the same reason, and `pubspec.yaml` now declares the six platforms
explicitly so the claim cannot silently regress the next time a dependency that
reaches `dart:io` is added.

Verified with the tool pub.dev itself uses:

```bash
dart pub global run pana --source path . --json | grep -o 'platform:[a-z]*' | sort -u
# android  ios  linux  macos  web  windows      (was: android ios linux macos windows)
```

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/autocomplete/auto_complete.dart` | **new** | the port — `AutoComplete`, `SortEngine`, `SortValue`, `_TrieSearchTree`, `TrieString`, `TrieNode` |
| `lib/src/autocomplete/autocompleter.dart` | modified | import rewired from `package:autotrie/autotrie.dart` to `auto_complete.dart` |
| `pubspec.yaml` | modified | `autotrie: ^2.0.0` removed, `platforms:` declaring all six added |
| `test/src/autocomplete/auto_complete_test.dart` | **new** | 29 tests over the ported surface |
| `CHANGELOG.md` | modified | `Unreleased › Added` entry |

## The port

The extracted surface is the in-memory half of `autotrie` 2.0.0:

- `AutoComplete` — minus `fromFile`, `persist` and `changedSincePersist`, the
  three members that reach `dart:io` and `hive`. None has a caller here.
- `SortEngine` — only the `entriesOnly` constructor survives. The others
  (`entriesAndTime`, `timeOnly`) scored on `SortValue.lastInsert`, and with the
  sort engine trimmed down to entry-count-only that field is nothing but
  bookkeeping. `msToNow` is dropped with them.
- `SortValue`, `_TrieSearchTree`, `TrieString`, `TrieNode` — carried over
  whole.

Two dead constructs were removed rather than ported, because they could never
do anything:

```dart
return base.children == <TrieNode>[];   // a fresh literal on every
                                        // evaluation, so always false
int get msToNow => ...                  // no caller left once the time
                                        // engines are gone
```

`_tree` became `final` and `TrieNode` gained the `hashCode` that overrides the
`==` it already had, because the lint asks for the pair.

## Two deliberate divergences from `autotrie`

The port is not bug-compatible in two places. `autotrie` is dormant since
2021-05-28 and cannot be fixed upstream; this repository owns the code now, so
the defects are corrected and pinned instead of carried forward. Neither
surface is reachable from `Autocompleter`, which only calls `clearEntries`,
`enterList` and `suggest`, so neither divergence can move the package's own
autocompletion behaviour.

**1. `contains` means "was entered", not "the characters exist".**

`_TrieSearchTree.search` walked the prefix and returned `true` on reaching the
end, never consulting the terminal `hits`. So an engine holding `alpha`
answered `true` for `alph` — and for `alpha` after it had been deleted. It now
returns `base.hits > 0`.

**2. `delete` removes the word it is told to remove.**

`_delete` returned `cur.children.isEmpty` at the terminal node and pruned only
childless, hitless nodes on the way back up. When a longer word shared the
prefix, the end node had a child, so nothing was ever pruned and **the terminal
node's `hits` were never cleared** — the word stayed suggested forever. Tracing
`delete('alpha')` on an engine holding `alpha` and `alphabet`: every
`shouldDeleteNode` on the way up is `false`, and `alpha` keeps `hits == 1`.

It now clears the hit first and prunes on `next.hits == 0`:

```dart
bool _delete(TrieNode cur, String word, int index) {
  if (index == word.length) {
    cur.hits = 0;
    return cur.children.isEmpty;
  }
  var ch = word[index];
  var next = cur.children[cur.children.indexOf(TrieNode(ch, index == word.length - 1))];
  var shouldDeleteNode = _delete(next, word, index + 1) && next.hits == 0;
  if (shouldDeleteNode) {
    cur.children.remove(next);
    return cur.children.isEmpty;
  }
  return false;
}
```

`test/src/autocomplete/auto_complete_test.dart` covers the trie order that
replaces the recency tie-break, the shared-prefix delete that used to fail, and
the full surface of the port — construction from a bank, `enter`, `enterList`,
`suggest`, `allEntries`, `isEmpty`, `contains`, `delete`, `clearEntries`,
`SortEngine`, `SortValue`, `TrieNode`, `TrieString`.
