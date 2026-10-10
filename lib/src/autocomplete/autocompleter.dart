import 'auto_complete.dart';
import 'package:highlight/highlight_core.dart';

import '../code/reg_exp.dart';

/// Accumulates textual data and suggests autocompletion based on it.
class Autocompleter {
  Mode? _mode;
  final _customAutocomplete = AutoComplete(engine: SortEngine.entriesOnly());
  final _keywordsAutocomplete = AutoComplete(engine: SortEngine.entriesOnly());
  final _textAutocompletes = <Object, AutoComplete>{};
  final _lastTexts = <Object, String>{};
  final _indexedWords = <Object, Set<String>>{};
  Set<String> _blacklistSet = const {};

  static final _whitespacesRe = RegExp(r'\s+');

  /// The language to automatically extract keywords from.
  Mode? get mode => _mode;

  set mode(Mode? value) {
    _mode = value;
    _parseKeywords();
  }

  void _parseKeywords() {
    _keywordsAutocomplete.clearEntries();

    final keywords = mode?.keywords;
    if (keywords == null) {
      return;
    }

    if (keywords is String) {
      _parseStringKeywords(keywords);
    } else if (keywords is Map<String, String>) {
      _parseStringStringKeywords(keywords);
    } else if (keywords is Map<String, dynamic>) {
      _parseStringDynamicKeywords(keywords);
    } else {
      throw Exception(
        'Unknown keywords type: ${keywords.runtimeType}, $keywords',
      );
    }
  }

  void _parseStringKeywords(String keywords) {
    _keywordsAutocomplete.enterList([
      ...keywords.split(_whitespacesRe).where((k) => k.isNotEmpty),
    ]);
  }

  void _addKeywords(Iterable<String> keywords) {
    _keywordsAutocomplete.enterList(
      keywords.where((k) => k.isNotEmpty).toList(growable: false),
    );
  }

  void _parseStringStringKeywords(Map<String, String> map) {
    map.values.forEach(_parseStringKeywords);
  }

  void _parseStringDynamicKeywords(Map<String, dynamic> map) {
    _addKeywords(map.keys);
  }

  /// The words to exclude from suggestions if they are otherwise present.
  List<String> get blacklist => _blacklistSet.toList(growable: false);

  set blacklist(List<String> value) {
    _blacklistSet = {...value};
  }

  /// Sets the [text] to parse all words from.
  /// Multiple texts are supported, each with its own [key].
  /// Use this to set current texts from multiple controllers.
  void setText(Object key, String? text) {
    if (text == null) {
      _textAutocompletes.remove(key);
      _lastTexts.remove(key);
      _indexedWords.remove(key);
      return;
    }

    if (text == _lastTexts[key]) {
      return;
    }

    final ac = _getOrCreateTextAutoComplete(key);
    _updateText(ac, key, text);
    _lastTexts[key] = text;
  }

  AutoComplete _getOrCreateTextAutoComplete(Object key) {
    return _textAutocompletes[key] ?? _createTextAutoComplete(key);
  }

  AutoComplete _createTextAutoComplete(Object key) {
    final result = AutoComplete(engine: SortEngine.entriesOnly());
    _textAutocompletes[key] = result;
    return result;
  }

  /// Indexes the words of [text] for [key] into [ac].
  ///
  /// Typing one character changes at most a couple of the document's words, so
  /// only the words that appeared are entered. Every word of the document used
  /// to be re-entered on every keystroke, which made the cost of a keystroke
  /// grow with the size of the file.
  void _updateText(AutoComplete ac, Object key, String text) {
    final words = _splitWords(text);
    final indexedWords = _indexedWords[key];

    if (indexedWords != null && indexedWords.every(words.contains)) {
      ac.enterList(words.difference(indexedWords).toList(growable: false));
    } else {
      // The incremental path above only ever adds words. Reaching this branch
      // means at least one indexed word left the document, and only a rebuild
      // drops it from the index.
      ac.clearEntries();
      ac.enterList(words.toList(growable: false));
    }

    _indexedWords[key] = words;
  }

  Set<String> _splitWords(String text) {
    return text
        // https://github.com/akvelon/flutter-code-editor/issues/61
        //.split(RegExps.wordSplit)
        .split(RegExp(RegExps.wordSplit.pattern))
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// Sets additional words to suggest.
  /// Fill this with your library's symbols.
  void setCustomWords(List<String> words) {
    _customAutocomplete.clearEntries();
    _customAutocomplete.enterList(words);
  }

  Future<List<String>> getSuggestions(String prefix) async {
    final result = {
      ..._customAutocomplete.suggest(prefix),
      ..._keywordsAutocomplete.suggest(prefix),
      ..._textAutocompletes.values
          .map((ac) => ac.suggest(prefix))
          .expand((e) => e),
    }.where((e) => !_blacklistSet.contains(e)).toList(growable: false);

    result.sort();
    return result;
  }
}
