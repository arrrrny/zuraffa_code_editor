import 'package:zuraffa_code_editor/src/search/settings.dart';
import 'package:zuraffa_code_editor/src/search/settings_controller.dart';
import 'package:zuraffa_code_editor/src/search/widget/search_settings_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Index 0 toggles case sensitivity, index 1 toggles the regular-expression
/// mode. [ToggleButtons] taps the child at that index.
Finder _toggle(int index) => find
    .descendant(
      of: find.byType(SearchSettingsWidget),
      matching: find.byType(Material),
    )
    .at(index);

void main() {
  group('SearchSettingsWidget', () {
    testWidgets('pressing a toggle flips the settings controller', (wt) async {
      final settings = SearchSettingsController();
      addTearDown(settings.dispose);
      final patternFocusNode = FocusNode();
      addTearDown(patternFocusNode.dispose);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchSettingsWidget(
              patternFocusNode: patternFocusNode,
              settingsController: settings,
            ),
          ),
        ),
      );

      expect(settings.value.isCaseSensitive, false);
      expect(settings.value.isRegExp, false);

      await wt.tap(_toggle(0));
      await wt.pumpAndSettle();
      expect(settings.value.isCaseSensitive, true);
      expect(settings.value.isRegExp, false);

      await wt.tap(_toggle(1));
      await wt.pumpAndSettle();
      expect(settings.value.isCaseSensitive, true);
      expect(settings.value.isRegExp, true);

      // The buttons are toggles, not one-shot switches.
      await wt.tap(_toggle(0));
      await wt.pumpAndSettle();
      expect(settings.value.isCaseSensitive, false);
      expect(settings.value.isRegExp, true);
    });

    testWidgets('rebuilds when the settings change', (wt) async {
      final settings = SearchSettingsController();
      addTearDown(settings.dispose);
      final patternFocusNode = FocusNode();
      addTearDown(patternFocusNode.dispose);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchSettingsWidget(
              patternFocusNode: patternFocusNode,
              settingsController: settings,
            ),
          ),
        ),
      );

      settings.value = const SearchSettings(
        isCaseSensitive: true,
        isRegExp: true,
        pattern: '',
      );
      await wt.pumpAndSettle();

      // Both toggles render their selected state; the swap happens through the
      // AnimatedBuilder on the controller, not by rebuilding the whole tree.
      expect(
        find.descendant(
          of: find.byType(SearchSettingsWidget),
          matching: find.byType(ToggleButtons),
        ),
        findsOneWidget,
      );
    });
  });
}
