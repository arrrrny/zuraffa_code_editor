import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'line_position_mapper.dart';

/// Re-editor-backed code controller (Phase 2).
///
/// Composition-based: `CodeLineEditingController` is factory-only, so
/// `CodeController` cannot subclass it. This wraps one and translates between
/// its line-addressed selection and the global offsets the rest of the package
/// uses.
class ReEditorCodeController {
  ReEditorCodeController({String text = ''})
    : _line = CodeLineEditingController.fromText(text);

  final CodeLineEditingController _line;

  CodeLineEditingController get lineController => _line;

  String get text => _line.text;

  set text(String value) {
    _line.codeLines = CodeLines.fromText(value);
  }

  /// The current selection, in global text offsets.
  TextSelection get selection {
    final s = _line.selection;
    final mapper = LinePositionMapper(text);
    final base = mapper.toOffset(s.baseIndex, s.baseOffset);
    final extent = mapper.toOffset(s.extentIndex, s.extentOffset);
    return TextSelection(baseOffset: base, extentOffset: extent);
  }

  set selection(TextSelection value) {
    final mapper = LinePositionMapper(text);
    final base = mapper.resolve(value.baseOffset);
    final extent = mapper.resolve(value.extentOffset);
    _line.selection = CodeLineSelection(
      baseIndex: base.line,
      baseOffset: base.column,
      extentIndex: extent.line,
      extentOffset: extent.column,
    );
  }

  void dispose() => _line.dispose();

  void addListener(VoidCallback l) => _line.addListener(l);
  void removeListener(VoidCallback l) => _line.removeListener(l);
}
