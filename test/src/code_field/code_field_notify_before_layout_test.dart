import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// Lays its child out, then runs [onLayout] from inside `performLayout()`.
///
/// Sibling before a [CodeField] in a `Column`, that puts [onLayout] in the
/// window akvelon/flutter-code-editor#275 (fork #32) crashes in: the editor
/// render box is mounted but the frame is still inside `flushLayout`, so the
/// box has no size yet.
class _NotifyOnLayout extends SingleChildRenderObjectWidget {
  const _NotifyOnLayout({required this.onLayout, super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderNotifyOnLayout(onLayout);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNotifyOnLayout renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderNotifyOnLayout extends RenderProxyBox {
  _RenderNotifyOnLayout(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}

void main() {
  testWidgets(
    'A controller notification landing while the frame is still laying out '
    'does not assert',
    (wt) async {
      // Mirrors akvelon/flutter-code-editor#275 (fork #32): analyzeCode()
      // notifies its listeners once the CodeField is already built but its
      // editor render box has not been laid out yet.
      final controller = createController('int a;');
      var notified = false;

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                _NotifyOnLayout(
                  onLayout: () {
                    if (notified) {
                      return;
                    }
                    notified = true;
                    controller.notifyListeners();
                  },
                  child: const SizedBox.shrink(),
                ),
                Expanded(
                  // GutterStyle.none keeps GutterWidget's AnimatedBuilder out
                  // of the tree: reacting to a mid-frame notification with
                  // setState throws 'Build scheduled during frame' no matter
                  // what this fix does, which is a separate pre-existing
                  // behaviour and not the crash reported in #32.
                  child: CodeField(
                    controller: controller,
                    focusNode: FocusNode(),
                    gutterStyle: GutterStyle.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(notified, true);
      expect(wt.takeException(), isNull);
    },
  );

  testWidgets('The deferred part of the mid-frame notification still applies', (
    wt,
  ) async {
    final controller = createController('int a;');
    var notified = false;

    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _NotifyOnLayout(
                onLayout: () {
                  if (notified) {
                    return;
                  }
                  notified = true;
                  controller.notifyListeners();
                },
                child: const SizedBox.shrink(),
              ),
              Expanded(
                child: CodeField(
                  controller: controller,
                  focusNode: FocusNode(),
                  gutterStyle: GutterStyle.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(notified, true);
    expect(wt.takeException(), isNull);

    // The notification that arrived mid-layout is not lost: a following
    // frame reads the now laid-out editor box without asserting.
    controller.notifyListeners();
    await wt.pump();
    expect(wt.takeException(), isNull);
  });
}
