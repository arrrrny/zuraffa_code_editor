import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Upstream #174 (synced here as #26): several `CodeField`s as the children of
/// a `TabBarView` crash with "Null check operator used on a null value" from a
/// post-frame callback registered in `initState`.
///
/// The callback reads the field's own `GlobalKey` to size the autocomplete and
/// search popups. `TabBarView` builds only the tab that is on screen, so the
/// field whose callback runs has always been laid out and the null-check
/// operators do not trip — which is why the reported crash does not reproduce.
void main() {
  CodeController field(String text) {
    final controller = CodeController(text: text);
    addTearDown(controller.dispose);
    return controller;
  }

  Widget tabs(int count) {
    return MaterialApp(
      home: DefaultTabController(
        length: count,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(
              tabs: [for (var i = 0; i < count; i++) Text('Tab $i')],
            ),
          ),
          body: TabBarView(
            children: [
              for (var i = 0; i < count; i++)
                CodeField(controller: field('void main() {\n  int i$i;\n}\n')),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('switching tabs between several CodeFields does not crash', (
    tester,
  ) async {
    await tester.pumpWidget(tabs(3));
    await tester.pumpAndSettle();

    expect(find.byType(CodeField), findsOneWidget);

    for (var index = 1; index < 3; index++) {
      await tester.tap(find.text('Tab $index'));
      await tester.pumpAndSettle();
    }

    // And back, so both directions of the transition have been exercised.
    await tester.tap(find.text('Tab 0'));
    await tester.pumpAndSettle();

    expect(find.byType(CodeField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tab that is never shown still builds without crashing', (
    tester,
  ) async {
    // Opening on the last tab: the earlier tabs are never built, so this pins
    // the never-shown configuration.
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 4,
          initialIndex: 3,
          child: Scaffold(
            appBar: AppBar(
              bottom: TabBar(
                tabs: [for (var i = 0; i < 4; i++) Text('Tab $i')],
              ),
            ),
            body: TabBarView(
              children: [
                for (var i = 0; i < 4; i++)
                  CodeField(controller: field('int i$i;\n')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('dropping a tab while another is on screen does not crash', (
    tester,
  ) async {
    await tester.pumpWidget(tabs(3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tab 2'));
    await tester.pumpAndSettle();

    // Open the autocomplete popup so the field is unmounted with a live
    // overlay of its own: the rebuild below drops the tab underneath it.
    final controller = tester
        .widget<CodeField>(find.byType(CodeField))
        .controller;
    controller.popupController.show(['foo']);
    await tester.pumpAndSettle();
    expect(find.text('foo'), findsOneWidget);

    // Rebuild the whole tree with fewer tabs: the ones that used to hold the
    // other fields go away underneath them.
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 1,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(tabs: [Tab(text: 'Tab 0')]),
            ),
            body: TabBarView(
              children: [CodeField(controller: field('a\nb\n'))],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
