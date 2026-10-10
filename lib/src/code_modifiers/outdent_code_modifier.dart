import 'package:flutter/material.dart';

import '../code_field/editor_params.dart';
import 'code_modifier.dart';

/// Removes one indent level when Backspace is pressed inside a line's leading
/// whitespace — the "outdent on Backspace" that issue #21 asks for.
///
/// The trigger is a deletion rather than a typed character, so this registers as
/// a deletion modifier: see [CodeModifier.deletesChar]. It keys on the space the
/// backspace removes, which is what a caret inside the leading whitespace always
/// sits behind. Without that registration no modifier could ever fire on a
/// backspace, which is the gap issue #21 reports.
///
/// Outside the leading whitespace it returns null and the ordinary
/// one-character delete stands, because a backspace that removes real code
/// should remove one character rather than reindent the line.
class OutdentModifier extends CodeModifier {
  const OutdentModifier() : super(' ', deletesChar: ' ');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    if (!sel.isCollapsed) {
      return null;
    }

    final caret = sel.start;
    if (caret == 0) {
      return null;
    }

    // Walk back to the start of the line. Any non-whitespace character before
    // the caret means the caret is not in the leading indentation.
    var lineStart = caret - 1;
    while (lineStart >= 0 && text[lineStart] != '\n') {
      if (text[lineStart] != ' ') {
        return null;
      }
      lineStart--;
    }

    final indent = caret - lineStart - 1;
    if (indent == 0) {
      return null;
    }

    // Remove a whole level, or whatever indentation is actually there when it
    // is not a multiple of tabSpaces — never more than the caret has behind it.
    final remove = params.tabSpaces.clamp(1, indent);

    return TextEditingValue(
      text: text.replaceRange(caret - remove, caret, ''),
      selection: TextSelection.collapsed(offset: caret - remove),
    );
  }
}
