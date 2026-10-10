import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// Upstream #174 (synced here as #26): several `CodeField`s as the children of
/// a `TabBarView` crash with "Null check operator used on a null value" from a
/// post-frame callback registered in `initState`.
///
/// The callback reads the field's own `GlobalKey` to size the autocomplete and
/// search popups. `TabBarView` keeps its offscreen tabs built, but a tab that
/// has never been laid out — or one that has already been torn down — has no
/// context with a size to read, so the null-check operators blow up instead of
/// the field staying quiet.
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

    expect(find.byType(CodeField), findsWidgets);

    for (var index = 1; index < 3; index++) {
      await tester.tap(find.text('Tab $index'));
      await tester.pumpAndSettle();
    }

    // And back, so both directions of the transition have been exercised.
    await tester.tap(find.text('Tab 0'));
    await tester.pumpAndSettle();

    expect(find.byType(CodeField), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tab that is never shown still builds without crashing', (
    tester,
  ) async {
    // Opening on the last tab is the case where the earlier tabs are built but
    // may not have been laid out yet when their post-frame callbacks run.
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
