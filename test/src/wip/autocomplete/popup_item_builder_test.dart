import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup.dart';
import 'package:zuraffa_code_editor/src/wip/autocomplete/popup_controller.dart';

/// A host that wants its own suggestion row. Upstream
/// `akvelon/flutter-code-editor#211` (our #87): "the widget cannot be
/// customized" — `Popup._buildListItem` builds the row inline, and neither
/// `Popup` nor `PopupController` is exported from the barrel, so a host cannot
/// even name the types to rebuild one.
///
/// The bare popup is pumped directly, the way `popup_placement_test.dart` does,
/// so each case pins one decision of the dispatch and nothing about placement.
/// These are written against the contract in
/// `.specify/specs/suggestion-popup-customization-87` and exist to be RED
/// before `CodeField.suggestionItemBuilder` does.
void main() {
  const suggestions = ['alpha', 'beta', 'gamma'];

  /// What the built-in row paints over the selected suggestion, and what it
  /// paints over every other one. Pinned here so the default-path assertion
  /// below is about the row the popup actually builds, not a shape I assumed.
  Color selectedTint() => Colors.blueAccent.withValues(alpha: 0.5);
  Color baseRowTint() => Colors.grey.withValues(alpha: 0.1);

  Future<(PopupController, FocusNode, List<int>)> pumpPopup(
    WidgetTester wt, {
    Widget Function(BuildContext, String, bool, VoidCallback)? itemBuilder,
    List<String> items = suggestions,
  }) async {
    final completions = <int>[];
    final controller = PopupController(
      onCompletionSelected: () => completions.add(1),
    );
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    controller.show(items);
    await wt.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: focusNode,
            child: Stack(
              children: [
                Popup(
                  controller: controller,
                  editingWindowSize: const Size(400, 600),
                  flippedOffset: Offset.zero,
                  normalOffset: Offset.zero,
                  parentFocusNode: focusNode,
                  style: const TextStyle(color: Colors.black),
                  backgroundColor: Colors.white,
                  suggestionItemBuilder: itemBuilder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await wt.pumpAndSettle();

    return (controller, focusNode, completions);
  }

  /// The row's own tint: the `Material` the built-in row wraps its `InkWell`
  /// in. Null when the row is not the built-in one — a host row has no InkWell
  /// to look up from, and no Material tint to find.
  Color? rowTint(WidgetTester wt, String text) {
    final material = find.ancestor(
      of: find.text(text),
      matching: find.byType(Material),
    );
    return material.evaluate().isEmpty
        ? null
        : wt.widget<Material>(material.first).color;
  }

  /// The row's selection tint: the `ColoredBox` the built-in row paints inside
  /// its `InkWell`. Null for a row that is not the built-in one.
  Color? selectionTint(WidgetTester wt, String text) {
    final row = find.ancestor(
      of: find.text(text),
      matching: find.byType(InkWell),
    );
    if (row.evaluate().isEmpty) {
      return null;
    }
    final box = find.descendant(of: row, matching: find.byType(ColoredBox));
    return box.evaluate().isEmpty
        ? null
        : wt.widget<ColoredBox>(box.first).color;
  }

  testWidgets('no builder: the built-in row is the one that renders', (
    wt,
  ) async {
    final (_, _, _) = await pumpPopup(wt);

    // The built-in chain: an InkWell per row, and the row's own tint, not a
    // host widget standing in for it. `beta` is an unselected row — `show`
    // leaves the first row selected, so the base tint lives on the others.
    expect(find.byType(InkWell), findsNWidgets(3));
    expect(rowTint(wt, 'beta'), baseRowTint());
  });

  testWidgets('the selected row carries the selection tint', (wt) async {
    await pumpPopup(wt);

    expect(selectionTint(wt, 'alpha'), selectedTint());
    expect(selectionTint(wt, 'beta'), Colors.transparent);
    expect(selectionTint(wt, 'gamma'), Colors.transparent);
  });

  testWidgets('a builder replaces the row for every suggestion', (wt) async {
    final seen = <String>[];

    await pumpPopup(
      wt,
      itemBuilder: (context, suggestion, isSelected, onSelect) {
        seen.add(suggestion);
        return Text(suggestion, textDirection: TextDirection.ltr);
      },
    );

    expect(seen, suggestions);
    // The built-in row is out of the tree, chain and all: no InkWell, no tint.
    expect(find.byType(InkWell), findsNothing);
    expect(selectionTint(wt, 'alpha'), isNull);
  });

  testWidgets('isSelected follows selectedIndex', (wt) async {
    final selected = <String>[];
    final (controller, _, _) = await pumpPopup(
      wt,
      itemBuilder: (context, suggestion, isSelected, onSelect) {
        if (isSelected) selected.add(suggestion);
        return Text(suggestion, textDirection: TextDirection.ltr);
      },
    );

    expect(selected, ['alpha']);

    controller.selectedIndex = 2;
    await wt.pumpAndSettle();

    expect(selected, ['alpha', 'gamma']);
  });

  testWidgets('onSelect commits the right suggestion and returns focus', (
    wt,
  ) async {
    final committed = <int>[];
    final (controller, focusNode, completions) = await pumpPopup(
      wt,
      itemBuilder: (context, suggestion, isSelected, onSelect) {
        return GestureDetector(
          onTap: () {
            committed.add(suggestions.indexOf(suggestion));
            onSelect();
          },
          child: Text(suggestion, textDirection: TextDirection.ltr),
        );
      },
    );

    expect(focusNode.hasFocus, isFalse);

    await wt.tap(find.text('gamma'));
    await wt.pumpAndSettle();

    expect(committed, [2]);
    expect(controller.selectedIndex, 2);
    expect(
      focusNode.hasFocus,
      isTrue,
      reason: 'focus must return to the editor',
    );
    expect(completions.length, 1);
  });

  testWidgets('a builder that ignores isSelected still commits correctly', (
    wt,
  ) async {
    // The host paints no selection of its own, so the commit path is the only
    // thing carrying the behaviour. It must not depend on the host having
    // read isSelected.
    final (controller, focusNode, completions) = await pumpPopup(
      wt,
      itemBuilder: (context, suggestion, isSelected, onSelect) {
        return GestureDetector(
          onTap: onSelect,
          child: Text(suggestion, textDirection: TextDirection.ltr),
        );
      },
    );

    await wt.tap(find.text('beta'));
    await wt.pumpAndSettle();

    expect(controller.selectedIndex, 1);
    expect(completions.length, 1);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('show resets the selection to the first row', (wt) async {
    final (controller, _, _) = await pumpPopup(wt);

    controller.selectedIndex = 2;
    controller.show(['delta', 'epsilon']);
    await wt.pumpAndSettle();

    // The observable sequence a host relies on: a fresh list always starts at
    // the top, whatever was selected before.
    expect(controller.selectedIndex, 0);
    expect(controller.suggestions, ['delta', 'epsilon']);
  });

  testWidgets('hide clears shouldShow and notifies', (wt) async {
    final (controller, _, _) = await pumpPopup(wt);

    var notified = 0;
    controller.addListener(() => notified++);

    controller.hide();
    await wt.pumpAndSettle();

    expect(controller.shouldShow, isFalse);
    expect(notified, 1);
  });
}
