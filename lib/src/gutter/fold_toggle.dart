import 'package:flutter/material.dart';

import 'clickable.dart';

class FoldToggle extends StatelessWidget {
  final Color? color;
  final bool isFolded;
  final VoidCallback onTap;

  /// Glyph size, and with it the toggle's own height.
  ///
  /// The gutter clamps it to the code line's height so a short line box keeps
  /// the toggle from setting its row's height and drifting every row below it
  /// off the code grid (#107).
  final double iconSize;

  const FoldToggle({
    super.key,
    required this.color,
    required this.isFolded,
    required this.onTap,
    this.iconSize = _defaultIconSize,
  });

  static const _defaultIconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    return ClickableWidget(
      onTap: onTap,
      child: RotatedBox(
        quarterTurns: isFolded ? 0 : 1,
        child: Icon(Icons.chevron_right, color: color, size: iconSize),
      ),
    );
  }
}
