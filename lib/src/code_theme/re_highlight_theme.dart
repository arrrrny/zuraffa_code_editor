import 'package:flutter/widgets.dart';
import 'package:highlight/highlight_core.dart' as hl;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart' as re;

import '../highlight/re_highlight_mode_converter.dart';
import 'code_theme_data.dart';

/// The key the language is registered under in the highlighting theme.
///
/// re_editor highlights with the single language it is given rather than
/// detecting one, so the key is never read as a language name — it only has
/// to be stable.
const String reHighlightLanguageKey = 'code';

final ReHighlightModeConverter _reHighlightModeConverter =
    ReHighlightModeConverter();

/// The converted grammar for [language].
///
/// The conversion is cached: a grammar is converted once and the result is
/// shared, which also keeps re_editor's per-editor highlighting from
/// recompiling the same grammar again and again.
final Map<hl.Mode, re.Mode> _convertedModes = {};

/// The re_highlight grammar [language] is highlighted with.
re.Mode reHighlightModeFor(hl.Mode language) {
  final cached = _convertedModes[language];
  if (cached != null) {
    return cached;
  }

  final converted = _reHighlightModeConverter.convert(language);
  _convertedModes[language] = converted;
  return converted;
}

/// The highlighting theme for [language], styled with [theme].
///
/// The theme's styles are handed to re_editor as they are. The grammars the
/// package ships name their scopes the way highlight.js v9 did — `class`,
/// `function`, `title`, `params`, `string` — and the themes the package
/// ships are keyed the same way, so the scopes a converted grammar emits and
/// the keys a theme carries line up without a translation.
CodeHighlightTheme buildReHighlightTheme({
  required hl.Mode language,
  required CodeThemeData? theme,
}) {
  return CodeHighlightTheme(
    languages: {
      reHighlightLanguageKey: CodeHighlightThemeMode(
        mode: reHighlightModeFor(language),
      ),
    },
    theme: theme?.styles ?? const <String, TextStyle>{},
  );
}
