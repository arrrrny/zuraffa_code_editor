import 'package:highlight/highlight_core.dart' as hl;
import 'package:re_highlight/re_highlight.dart' as re;

import 'mode_patches.dart';

/// Converts a `package:highlight` grammar into an equivalent `re_highlight`
/// grammar.
///
/// The two engines share the highlight.js grammar shape, so the conversion is
/// a field rename plus the few places where the two disagree on a field's
/// type. A highlight.js v9 mode names its scope `className`; re_highlight
/// calls the same field `scope`, and the name is carried over under it, so the
/// scopes the converted grammar emits are the ones the original emitted.
///
/// The converted grammar is not registered with re_highlight: re_editor takes
/// the mode directly and compiles it per editor.
class ReHighlightModeConverter {
  /// Converted modes, keyed by the mode they came from.
  ///
  /// A grammar shares one mode object between many places — the shipped
  /// languages do it for their number and comment modes — and the conversion
  /// is not free, so each mode is converted once. `Mode` defines no
  /// `operator==`, so the map is keyed by identity, which is what sharing a
  /// mode object means here.
  final Map<hl.Mode, re.Mode> _converted = {};

  /// The re_highlight grammar for [mode].
  ///
  /// The mode handed in is the one the package would hand to its own
  /// highlighter, so the patches that fix a language's defects apply to the
  /// converted grammar too.
  re.Mode convert(hl.Mode mode) {
    final patched = modeToRegister(mode);
    return _convert(patched);
  }

  re.Mode _convert(hl.Mode mode) {
    final cached = _converted[mode];
    if (cached != null) {
      return cached;
    }

    final converted = re.Mode(
      ref: mode.ref,
      aliases: mode.aliases,
      keywords: _convertKeywords(mode.keywords),
      illegal: mode.illegal,
      caseInsensitive: mode.case_insensitive,
      scope: _scopeOf(mode),
      begin: mode.begin,
      beginKeywords: mode.beginKeywords,
      end: mode.end,
      lexemes: mode.lexemes,
      endSameAsBegin: mode.endSameAsBegin,
      endsParent: mode.endsParent,
      endsWithParent: mode.endsWithParent,
      relevance: mode.relevance?.toDouble(),
      subLanguage: mode.subLanguage,
      excludeBegin: mode.excludeBegin,
      excludeEnd: mode.excludeEnd,
      skip: mode.skip,
      returnBegin: mode.returnBegin,
      returnEnd: mode.returnEnd,
      self: mode.self,
      disableAutodetect: mode.disableAutodetect,
    );

    // Registered before the children are converted: a grammar may reach
    // itself through a shared mode, and the cycle must resolve to the mode
    // already under construction.
    _converted[mode] = converted;

    converted.refs = mode.refs?.map(
      (key, value) => MapEntry(key, _convert(value)),
    );
    converted.contains = _convertModes(mode.contains);
    converted.variants = _convertModes(mode.variants);
    converted.starts = mode.starts == null ? null : _convert(mode.starts!);

    return converted;
  }

  /// The scope a mode names.
  ///
  /// A highlight.js v9 mode names its scope `className`; re_highlight calls
  /// the same thing `scope` and keeps the old name only as a deprecated
  /// fallback its compiler reads once. The scope is carried over under the
  /// name re_highlight reads it by, so the scope is there before the grammar
  /// is compiled — the compiler only fills `scope` from `className` when the
  /// grammar is compiled, and a grammar that is inspected before that would
  /// look unscoped.
  ///
  /// The `delete` scope is dropped, which is what re_highlight's own
  /// compiler does with it.
  String? _scopeOf(hl.Mode mode) {
    final className = mode.className;
    if (className == null || className == 'delete') {
      return null;
    }
    return className;
  }

  /// The modes of a grammar's `contains` or `variants` list.
  ///
  /// The two lists may hold a null entry — a grammar can leave a slot empty —
  /// and re_highlight's compiler walks them without a null check, so the
  /// empty slots are dropped here.
  List<re.Mode>? _convertModes(List<hl.Mode?>? modes) {
    if (modes == null) {
      return null;
    }

    final converted = <re.Mode>[];
    for (final mode in modes) {
      if (mode != null) {
        converted.add(_convert(mode));
      }
    }

    return converted;
  }

  /// The keywords of a mode, in the shape re_highlight's keyword compiler
  /// reads.
  ///
  /// A keyword list is a scope name and the words under it; the words are
  /// separated by spaces, so a list with a double space in it would compile
  /// into an empty keyword that matches everywhere. The words are split here
  /// instead, which drops the empty ones.
  dynamic _convertKeywords(dynamic keywords) {
    if (keywords is String) {
      return _splitKeywords(keywords);
    }

    if (keywords is Map) {
      final converted = <String, dynamic>{};
      keywords.forEach((key, value) {
        if (key == r'$pattern') {
          // The keyword pattern is a regular expression, not a word list.
          converted[key] = value;
          return;
        }
        if (value is String) {
          converted[key] = _splitKeywords(value);
        } else if (value is List) {
          converted[key] = value
              .whereType<String>()
              .where((w) => w.isNotEmpty)
              .toList();
        } else {
          converted[key] = value;
        }
      });
      return converted;
    }

    if (keywords is List) {
      return keywords.whereType<String>().where((w) => w.isNotEmpty).toList();
    }

    return keywords;
  }

  List<String> _splitKeywords(String keywords) {
    return keywords
        .split(RegExp(r'\s+'))
        .where((keyword) => keyword.isNotEmpty)
        .toList();
  }
}
