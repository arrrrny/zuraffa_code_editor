import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/java.dart';

/// Java's triple-quoted string literal.
///
/// The shipped java mode has no triple-quote mode, so the third `"` of `"""`
/// opens an ordinary string whose content crosses a newline — and an ordinary
/// string declares a newline illegal, which aborts the parse and takes the
/// whole document's highlighting with it. Listed ahead of the single-quoted
/// string modes so `"""` is matched before a lone `"` is.
final _tripleQuotedString = Mode(
  className: 'string',
  begin: '"""',
  end: '"""',
  relevance: 0,
);

/// The java mode to parse with, with the two defects that cost a document its
/// highlighting removed.
///
/// The shipped mode declares `illegal: "<\\/|#"`. `_parse` throws on an
/// illegal lexeme, catches the throw itself and hands back the entire document
/// as one unclassified node, so a single `#` outside a comment or a string
/// literal — or a stray `</` — erases every other class in the file.
///
/// A copy, not the shipped mode with a field cleared: `Mode` caches the
/// regexes compiled from `illegal` and `contains` on the first parse, so
/// editing the shipped mode after it has been compiled leaves the stale
/// regexes in place. [Mode] defines no `operator==`, so [modeToRegister]'s
/// identity check still matches the mode the caller supplied.
final _patchedJava = Mode(
  refs: java.refs,
  aliases: java.aliases,
  keywords: java.keywords,
  contains: [_tripleQuotedString, ...java.contains ?? const <Mode?>[]],
);

/// The mode to hand to [highlight.registerLanguage] for the caller's [mode].
///
/// A language this package does not know a defect in is registered exactly as
/// it was supplied. `CodeController` keeps the supplied mode everywhere else —
/// `language`, the autocompleter and `SingleLineComments.byMode` all key on the
/// original — so only the highlight parse sees the replacement.
Mode modeToRegister(Mode mode) => mode == java ? _patchedJava : mode;
