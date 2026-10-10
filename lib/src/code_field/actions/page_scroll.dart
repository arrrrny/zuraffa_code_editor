import 'package:flutter/material.dart';

/// Page Up / Page Down, so the editor scrolls like any other text field.
///
/// Flutter binds these keys at the app level
/// (`DefaultTextEditingShortcuts`), where `ScrollAction` resolves the
/// nearest scrollable by walking *up* from the app root — never finding
/// the editor's own scrollable, which lives below the field. The
/// `CodeField` therefore binds them itself and scrolls its own
/// controller, which keeps the linked gutter in sync.
class PageScrollIntent extends Intent {
  const PageScrollIntent({required this.forward});

  /// Scroll down (Page Down) when true, up (Page Up) when false.
  final bool forward;
}

class PageScrollAction extends Action<PageScrollIntent> {
  PageScrollAction({required this.scrollController, required this.pageHeight});

  /// The field's vertical scroll controller, linked to the gutter's.
  final ScrollController? scrollController;

  /// The height of one page — the editor box's height.
  final double Function() pageHeight;

  @override
  Object? invoke(PageScrollIntent intent) {
    final controller = scrollController;
    if (controller == null || !controller.hasClients) {
      return null;
    }

    final position = controller.position;
    final height = pageHeight();
    if (height <= 0) {
      return null;
    }

    final target = position.pixels + (intent.forward ? height : -height);
    controller.animateTo(
      target
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
    return null;
  }
}
