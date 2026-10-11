import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../sizes.dart';
import 'popup_controller.dart';

/// Popup window displaying the list of possible completions
class Popup extends StatefulWidget {
  final PopupController controller;

  /// The window size the popup has to stay inside.
  ///
  /// The field hands it the real window's size: the popup is inserted into the
  /// root overlay, so it is placed at window coordinates, and the editor's own
  /// render box is the smaller rectangle whenever the editor is narrower than
  /// the window.
  final Size editingWindowSize;

  /// The window coordinates of the highest allowed top-left corner
  /// of the popup if shown above the caret.
  ///
  /// Since the popup is pushed to the bottom of the allowed rectangle
  /// the actual position may be lower.
  final Offset flippedOffset;

  /// The window coordinates of the top-left corner of the popup
  /// if shown below the caret.
  final Offset normalOffset;

  final FocusNode parentFocusNode;
  final TextStyle style;
  final Color? backgroundColor;

  const Popup({
    super.key,
    required this.controller,
    required this.editingWindowSize,
    required this.flippedOffset,
    required this.normalOffset,
    required this.parentFocusNode,
    required this.style,
    this.backgroundColor,
  });

  @override
  PopupState createState() => PopupState();
}

class PopupState extends State<Popup> {
  final pageStorageBucket = PageStorageBucket();

  @override
  void initState() {
    widget.controller.addListener(rebuild);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The window this popup has to stay inside. The field hands it the real
    // window's size — not the editor's own render box, which is the smaller
    // rectangle whenever the editor is narrower than the window.
    final windowSize = widget.editingWindowSize;
    final neededHeight = _neededPopupHeight(context);
    final verticalFlipRequired =
        widget.normalOffset.dy + neededHeight > windowSize.height;

    // Fixes assertion error when ISC isn't attached but _attach method
    // of ISC instance are being called
    ItemScrollController? isc;
    if (widget.controller.itemScrollController.isAttached) {
      isc = widget.controller.itemScrollController;
    }

    // The popup is in the root overlay at window coordinates, so its position
    // is clamped into the window itself. The flipped box is bottom-aligned and
    // as tall as the popup's maximum, while the unflipped one is top-aligned
    // and as tall as the suggestions need — each clamps on the edge its own
    // alignment can cross.
    final double top = verticalFlipRequired
        ? _clampIntoWindow(
            widget.flippedOffset.dy,
            windowSize.height - Sizes.autocompletePopupMaxHeight,
          )
        : _clampIntoWindow(
            widget.normalOffset.dy,
            windowSize.height - neededHeight,
          );

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: _clampIntoWindow(
          widget.normalOffset.dx,
          windowSize.width - Sizes.autocompletePopupMaxWidth,
        ),
        top: top,
        child: Container(
          alignment: verticalFlipRequired
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          constraints: const BoxConstraints(
            maxHeight: Sizes.autocompletePopupMaxHeight,
            maxWidth: Sizes.autocompletePopupMaxWidth,
          ),
          // Container is used because the vertical borders
          // in DecoratedBox are hidden under scroll.
          // ignore: use_decorated_box
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: Border.all(color: widget.style.color!, width: 0.5),
            ),
            child: ScrollablePositionedList.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemScrollController: isc,
              itemPositionsListener: widget.controller.itemPositionsListener,
              itemCount: widget.controller.suggestions.length,
              itemBuilder: (context, index) {
                return _buildListItem(index);
              },
            ),
          ),
        ),
      ),
    );
  }

  double _clampIntoWindow(double offset, double limit) =>
      offset.clamp(0, math.max(0, limit));

  /// The height the suggestions actually need: one row each, capped at the
  /// popup's maximum height. The flip is decided on this rather than on the
  /// maximum, so a single suggestion near the bottom of the window no longer
  /// jumps above the caret.
  double _neededPopupHeight(BuildContext context) {
    final suggestions = widget.controller.suggestions;
    if (suggestions.isEmpty) {
      return 0;
    }
    return math.min(
      suggestions.length * _rowHeight(context),
      Sizes.autocompletePopupMaxHeight,
    );
  }

  /// Height of one suggestion row. The rows render a `Text` that inherits the
  /// ambient default style, so the same merged style is measured here.
  double _rowHeight(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final painter = TextPainter(
      text: TextSpan(text: widget.controller.suggestions.first, style: style),
      textDirection: Directionality.of(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  Widget _buildListItem(int index) {
    return Material(
      color: Colors.grey.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
          widget.controller.onCompletionSelected();
        },
        hoverColor: Colors.grey.withOpacity(0.1),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ColoredBox(
          color: widget.controller.selectedIndex == index
              ? Colors.blueAccent.withOpacity(0.5)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.controller.suggestions[index],
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }

  void rebuild() {
    setState(() {});
  }
}
