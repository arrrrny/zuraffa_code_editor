import 'package:highlight/highlight_core.dart';

import '../../code/code_lines.dart';
import '../../highlight/result.dart';
import '../foldable_block_type.dart';
import 'abstract.dart';

/// The [Node.className] highlight gives to a markup element, either
/// `<element>` or `</element>`.
const _tagClassName = 'tag';

/// The first child of an opening tag, e.g. `<a>`.
const _openingTagOpener = '<';

/// The first child of a closing tag, e.g. `</a>`.
const _closingTagOpener = '</';

/// The suffix of the last child of a self-closing tag, e.g. `<br/>`
/// or `<img src="x" />`.
const _selfClosingTagSuffix = '/>';

/// A parser for foldable blocks in markup: XML.
///
/// Markup nests on `<element>` / `</element>` rather than on brackets, so the
/// generic bracket-driven parser opens no blocks in it at all. The structure
/// here comes from highlight's nodes, which means a `<` inside a comment, a
/// CDATA section, a processing instruction or an attribute value can never be
/// mistaken for an element.
///
/// Closing tags close the innermost open block, exactly the way brackets do.
/// A `<tag>text</tag>` pair on one line produces no block, and an unclosed
/// element is reported as invalid rather than silently ignored.
class MarkupFoldableBlockParser extends AbstractFoldableBlockParser {
  @override
  void parse({
    required Result highlighted,
    required Set<Object?> serviceCommentsSources,
    required CodeLines lines,
  }) {
    highlighted.forEachNode(_visitTag);
    finalize();
  }

  void _visitTag(Node node, int lineIndex, int charIndex) {
    if (node.className != _tagClassName) {
      return;
    }

    final children = node.children;
    if (children == null || children.isEmpty) {
      return;
    }

    final opener = children.first.value;
    if (opener == _closingTagOpener) {
      endBlock(lineIndex, FoldableBlockType.markup);
      return;
    }

    if (opener == _openingTagOpener) {
      // A self-closing tag carries its slash in the last child, because the
      // attributes sit in between: `<br/>` ends with `/>`,
      // `<img src="x" />` ends with ` />`.
      final closer = children.last.value;
      if (closer == null || !closer.endsWith(_selfClosingTagSuffix)) {
        startBlock(lineIndex, FoldableBlockType.markup);
      }
    }
  }
}
