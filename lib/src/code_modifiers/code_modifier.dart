import 'package:flutter/material.dart';

import '../code_field/editor_params.dart';

abstract class CodeModifier {
  /// The character whose insertion this modifier reacts to.
  final String char;

  /// The character whose deletion this modifier reacts to, or null when this is
  /// an insertion-only modifier.
  ///
  /// A deletion inserts no character, so [CodeController] cannot key its dispatch
  /// on anything the typed stream carries — it keeps a map of its own for these,
  /// and a modifier that sets this field is looked up in that map instead.
  /// This is what makes "outdent on Backspace" implementable from outside the
  /// package; without it no modifier can ever fire on a backspace, which is the
  /// gap issue #21 reports.
  ///
  /// The two registrations are exclusive: setting this field keeps [char] out
  /// of the insertion map, so a modifier that must react to both a typed
  /// character and a deleted one needs two instances, one for each.
  final String? deletesChar;

  const CodeModifier(this.char, {this.deletesChar});

  /// Helper to insert [str] in [text] between [start] and [end]
  TextEditingValue replace(String text, int start, int end, String str) {
    final len = str.length;
    return TextEditingValue(
      text: text.replaceRange(start, end, str),
      selection: TextSelection(
        baseOffset: start + len,
        extentOffset: start + len,
      ),
    );
  }

  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  );
}
