# Fix: java-hash-strings-104

## Root cause

`highlight` 0.7.0's `_parse` throws on an illegal lexeme, catches its own throw,
and returns the entire document as one unclassified node
(`highlight-0.7.0/lib/src/highlight.dart:442-491`). A bail is therefore silent:
the caller sees a normal-looking `Result` whose `nodes` is a single node with no
class covering the whole source, and every character renders in the default
colour.

Three things in the `java` mode can trigger it:

1. `illegal: "<\\/|#"` on the mode itself — a `#` or a stray `</` that is not
   already inside a comment or a string.
2. `QUOTE_STRING_MODE`'s `illegal: '\n'`, reached by a triple-quoted literal.
3. `APOS_STRING_MODE`'s `illegal: '\n'`, reached the same way with `'`.

## Changes

| file | change |
|---|---|
| `lib/src/highlight/mode_patches.dart` | new — the `"""…"""` string mode, the repaired `java` copy, and `modeToRegister` |
| `lib/src/code_field/code_controller.dart` | `registerLanguage(_languageId, modeToRegister(language))` |
| `test/src/highlight/java_language_test.dart` | new — 8 tests |
| `CHANGELOG.md` | Unreleased → Fixed |
| `README.md` | `#### Java: # and triple-quoted strings` under Syntax Highlighting |

## Why a copy of the mode

`Mode` caches the regexes compiled from `illegal` and `contains` on the first
parse — `_compileMode` builds `illegalRe` and `terminators`, then sets
`compiled = true`, and every later parse early-returns. So clearing `illegal`
on the shipped mode is only sometimes effective: it works if that mode has not
been compiled yet, and silently does nothing if it has, which depends on
whether anything else in the process parsed `java` first. A fresh copy is always
recompiled, so the repair cannot be defeated by ordering.

## Why the triple-quote mode is listed first

`_compileMode` builds a mode's terminator regex from its `contains` begins
joined by `|` in order, and Dart alternation is leftmost-first at a given
position. At the first `"` of `"""` both `"""` and a lone `"` can match; listing
the triple-quote mode first makes the three-quote form win, and a lone `"`
still reaches `QUOTE_STRING_MODE` normally.

## Notes

- The repaired copy shares the shipped mode's child `Mode` objects. The
  highlighter compiles those on first use, which is idempotent and is what a
  direct `highlight.parse(x, language: 'java')` does anyway.
- `keywords` is passed through as-is. If the shipped mode has been compiled it
  is already a flattened map, which `_compileMode` accepts; if it has not, it is
  the original string and the copy flattens its own field, leaving the shipped
  mode's untouched.
- `refs` and `aliases` are carried over: `_pointToRef` dereferences
  `_languageMode.refs!` during compilation, so a null `refs` would be a crash,
  not a fallback.
