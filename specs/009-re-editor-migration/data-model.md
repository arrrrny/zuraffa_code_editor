# Data Model: Re-editor Migration

## CodeController

- **text**: full source string (independent of folds)
- **selection**: TextSelection
- **code**: CodeLine collection (from re_editor)
- **foldedBlocks**: list of FoldableBlock
- **hiddenLineRanges**: HiddenLineRanges
- **analysisResult**: analyzer result
- **language**: Mode?

## FoldableBlock

- **firstLine**: int
- **lastLine**: int (closing line, kept visible when folded)

## HiddenLineRanges

- **ranges**: list of (start, end) line index pairs
- **visibleLineNumbers**: iterable of visible line indices

## CodeTheme / CodeThemeData

- **styles**: Map<String, TextStyle>

## Autocompleter

- **customWords**: Set<String>
- **mode**: Mode?