# Test List: List web as a supported platform

- **Slug**: list-web-as-supported-platform
- **Issue**: 23
- **File**: `test/src/autocomplete/auto_complete_test.dart`

The port's in-memory surface has no caller inside the package beyond
`clearEntries`, `enterList` and `suggest`, and the coverage gate asks that every
line of code this repository owns be reached. `contains`, `delete`, `allEntries`
and the trie primitives are therefore tested directly.

| # | Test | Status |
|---|---|---|
| 1 | a bank is entered word by word | pass |
| 2 | an empty bank leaves the engine empty | pass |
| 3 | an empty string bank entry is kept | pass |
| 4 | a repeated entry is promoted above a single one | pass |
| 5 | a tie keeps trie order, not recency | pass (was RED) |
| 6 | `enterList` enters every entry | pass |
| 7 | `enterList` counts repeats across calls | pass |
| 8 | `suggest` with an unmatched prefix suggests nothing | pass |
| 9 | a complete word is its own suggestion | pass |
| 10 | an empty prefix suggests everything | pass |
| 11 | `allEntries` lists every entered word | pass |
| 12 | an empty engine has no entries | pass |
| 13 | a word is listed once however often it was entered | pass |
| 14 | `isEmpty` is false once an entry is entered | pass |
| 15 | `contains` finds an entered word | pass |
| 16 | `contains` rejects a word that was never entered | pass |
| 17 | `contains` rejects a prefix of an entered word | pass (was RED) |
| 18 | `contains` rejects a prefix that was never entered | pass |
| 19 | `delete` removing an entry stops it being suggested | pass |
| 20 | a removed entry can be entered again | pass |
| 21 | removing a shared prefix keeps the longer word | pass (was RED) |
| 22 | the survivor of a shared-prefix delete is deletable too | pass |
| 23 | removing the longer word keeps the shared prefix | pass |
| 24 | removing one of two sharing a prefix keeps the other | pass |
| 25 | deleting from an empty engine does nothing | pass |
| 26 | deleting a word that is not there does nothing | pass |
| 27 | `clearEntries` empties the engine | pass |
| 28 | the engine is usable again after `clearEntries` | pass |
| 29 | `SortEngine.entriesOnly` scores by the entry count alone | pass |
| 30 | `SortValue` carries the recency and the entry count | pass |
| 31 | `TrieNode` compares by value only | pass |
| 32 | `TrieNode.hashCode` agrees with the equality it overrides | pass |
| 33 | `TrieString` renders its value, hits and recency | pass |

Red tests 5, 17 and 21 were the three expectations the first pass got wrong, and
each one is fixed in `lib/` rather than in the test — see the "Two deliberate
divergences" section of `./implement.md`.
