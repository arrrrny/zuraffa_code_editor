// TODO(nausharipov): where to store constants?

/// Vertical padding the editor's `TextField` (`contentPadding`) and the
/// gutter's outer `Padding` both carry on each edge.
///
/// They must stay equal: `_CodeFieldState` compares the two scroll extents by
/// subtracting one combined insets figure from the editor's, so a gutter or
/// field padded off this constant would leave the comparison permanently
/// unable to match. Both paddings read it from here so they move together.
const double codeFieldVerticalPadding = 16;

class Sizes {
  static const double autocompletePopupMaxHeight = 100;
  static const double autocompletePopupMaxWidth = 300;
  static const caretPadding = 10;
}
