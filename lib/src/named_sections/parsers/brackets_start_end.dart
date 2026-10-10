import 'dart:math';

import '../../single_line_comments/single_line_comment.dart';
import '../named_section.dart';
import 'abstract.dart';

/// Parses named sections from tags like [START name]...[END name].
///
/// Section name may only contain english letters, numbers, and underscores.
/// Section name must not be empty.
/// Whitespaces are allowed before START/END, before name, and after name.
///
/// Sections can overlap and can be nested.
///
/// A section can start and end on the same line in a single comment or in two
/// different comments.
///
/// If a section is never started, it starts at the line 0.
/// If a section is never ended, its `lastLine` is `null`.
///
/// If a section is started multiple times, the min line number takes effect.
/// If a section is ended multiple times, the max line number takes effect.
///
/// The order of comments in the list does not matter.
class BracketsStartEndNamedSectionParser extends AbstractNamedSectionParser {
  const BracketsStartEndNamedSectionParser();

  /// The patterns a comment's content must match to carry this parser's
  /// start or end tag. Group 3 is the section name. Public so the tag
  /// recognition stays in one place — consumers that need to tell a
  /// section's own tag from an unrelated comment match with these, too.
  static final startRe = RegExp(r'\[(\s*)START(\s+)([_0-9a-zA-Z]+)(\s*)\]');
  static final endRe = RegExp(r'\[(\s*)END(\s+)([_0-9a-zA-Z]+)(\s*)\]');

  @override
  List<NamedSection> parseUnsorted({
    required List<SingleLineComment> singleLineComments,
  }) {
    final firsts = <String, int>{};
    final lasts = <String, int>{};

    for (final comment in singleLineComments) {
      for (final match in startRe.allMatches(comment.innerContent)) {
        final name = match.group(3) ?? '';
        final oldFirst = firsts[name];
        firsts[name] = oldFirst == null
            ? comment.lineIndex
            : min(comment.lineIndex, oldFirst);
      }

      for (final match in endRe.allMatches(comment.innerContent)) {
        final name = match.group(3) ?? '';
        lasts[name] = max(comment.lineIndex, lasts[name] ?? 0);
      }
    }

    return _combineFirstsAndLasts(firsts, lasts);
  }

  List<NamedSection> _combineFirstsAndLasts(
    Map<String, int> firsts,
    Map<String, int> lasts,
  ) {
    final sections = <NamedSection>[];

    for (final entry in lasts.entries) {
      final name = entry.key;
      final last = entry.value;

      sections.add(
        NamedSection(firstLine: firsts[name] ?? 0, lastLine: last, name: name),
      );

      firsts.remove(name);
    }

    for (final entry in firsts.entries) {
      final name = entry.key;
      final first = entry.value;

      sections.add(
        NamedSection(firstLine: first, lastLine: lasts[name], name: name),
      );
    }

    return sections;
  }
}
