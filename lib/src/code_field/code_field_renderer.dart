/// The renderer a code field draws the code with.
enum CodeFieldRenderer {
  /// The text field renderer.
  ///
  /// The code is drawn by Flutter's own text field, which lays the whole
  /// document out — one paragraph for the entire text — on every change.
  textField,

  /// The re_editor renderer.
  ///
  /// The code is drawn by re_editor, which lays out only the lines that are
  /// on screen, so a document of any length costs the same to draw as a
  /// document of one screen.
  reEditor,
}
