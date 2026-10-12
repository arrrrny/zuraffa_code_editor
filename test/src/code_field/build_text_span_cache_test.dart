// ignore_for_file: discarded_futures

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code_field/code_controller.dart';
import 'package:zuraffa_code_editor/src/code_field/code_field.dart';
import 'package:zuraffa_code_editor/src/code_field/search_result_highlighted_builder.dart';
import 'package:zuraffa_code_editor/src/code_theme/code_theme.dart';
import 'package:zuraffa_code_editor/src/code_theme/code_theme_data.dart';
import 'package:zuraffa_code_editor/src/search/settings.dart';

import '../common/create_app.dart';

const _text = 'void main() {\n  int a = 1;\n}\n';

/// Every test that asserts invalidation is in two parts: a **hit at baseline**
/// first, then the change. Without the first half the second half is vacuous —
/// "a different object" is true of any implementation that caches nothing, so it
/// would pass before this feature exists and keep passing after someone deleted
/// the cache. The first half is what makes the second half mean anything.
Future<(CodeController, BuildContext)> _pump(
  WidgetTester wt, {
  String text = _text,
  CodeThemeData? theme,
  bool withLanguage = true,
}) async {
  final controller = withLanguage
      ? createController(text)
      : CodeController(text: text);
  addTearDown(controller.dispose);

  focusNode = FocusNode();
  final field = CodeField(controller: controller, focusNode: focusNode);

  await wt.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: theme == null ? field : CodeTheme(data: theme, child: field),
      ),
    ),
  );
  focusNode.requestFocus();

  return (controller, wt.element(find.byType(CodeField)));
}

TextSpan _span(
  CodeController controller,
  BuildContext context, {
  TextStyle? style = const TextStyle(),
}) => controller.buildTextSpan(context: context, style: style);

/// The analysis debounce is a 500 ms timer on the controller, and the binding
/// fails a widget test that still has one pending when the tree goes down.
Future<void> _settle(WidgetTester wt, CodeController controller) async {
  controller.dismiss();
  await wt.pump(const Duration(seconds: 10));
}

/// Leaves in paint order, the shape the framework walks.
///
/// `InlineSpan.visitChildren` already walks pre-order itself — including this
/// span — so the visitor must only collect. Calling `visitChildren` from inside
/// the visitor re-enters the same span and recurses forever.
List<TextSpan> _leavesOf(InlineSpan span) {
  final leaves = <TextSpan>[];

  span.visitChildren((span) {
    if (span is TextSpan && (span.text?.isNotEmpty ?? false)) {
      leaves.add(span);
    }
    return true;
  });

  return leaves;
}

/// `(text, style)` per leaf. Structural, so a change in either half is caught.
List<(String?, TextStyle?)> _fingerprintOf(InlineSpan span) =>
    _leavesOf(span).map((leaf) => (leaf.text, leaf.style)).toList();

/// The text of the match the search panel paints as current, i.e. the one behind
/// `SearchNavigationState.currentMatchIndex`.
String _currentMatchTextOf(InlineSpan span) => _leavesOf(span)
    .where((leaf) => leaf.style?.backgroundColor == currentMatchBackgroundColor)
    .map((leaf) => leaf.text)
    .join();

/// Text of every match-painted leaf, current or not. Which matches are painted
/// is part of the tree, so this is what separates two patterns that leave the
/// current match in the same place.
String _matchTextsOf(InlineSpan span) => _leavesOf(span)
    .where(
      (leaf) =>
          leaf.style?.backgroundColor == matchBackgroundColor ||
          leaf.style?.backgroundColor == currentMatchBackgroundColor,
    )
    .map((leaf) => leaf.text)
    .join();

CodeThemeData get _theme =>
    CodeThemeData(keywordStyle: const TextStyle(color: Color(0xFFE040FB)));

SearchSettings get _patternA =>
    const SearchSettings(isCaseSensitive: false, isRegExp: false, pattern: 'a');

/// Over `'int Aa = 1;\nint ab = 2;\n'` this matches the one word `Aa` where
/// `_patternA` matches three single characters, and both leave the current
/// match at index 0.
SearchSettings get _patternB => const SearchSettings(
  isCaseSensitive: false,
  isRegExp: false,
  pattern: 'Aa',
);

void main() {
  group('CodeController.buildTextSpan caching', () {
    testWidgets('a repeated call returns the very same object', (wt) async {
      final (controller, context) = await _pump(wt);

      final first = _span(controller, context);
      final second = _span(controller, context);

      expect(
        identical(first, second),
        isTrue,
        reason:
            'Nothing changed between the calls, so the tree the first call '
            'built is still the tree that renders. Rebuilding it means '
            'walking and allocating the whole document on every rebuild.',
      );
      expect(controller.lastTextSpan, same(second));

      await _settle(wt, controller);
    });

    testWidgets('a notification that changes nothing still hits', (wt) async {
      final (controller, context) = await _pump(wt);

      final before = _span(controller, context);
      expect(identical(before, _span(controller, context)), isTrue);

      // A selection move is the commonest rebuild trigger there is, and it
      // reaches neither `_code` nor any other key component.
      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(identical(before, _span(controller, context)), isTrue);

      await _settle(wt, controller);
    });

    testWidgets('typing invalidates', (wt) async {
      final (controller, context) = await _pump(wt);

      final before = _span(controller, context);
      expect(identical(before, _span(controller, context)), isTrue);

      controller.text = '${_text}void';

      final after = _span(controller, context);
      expect(identical(before, after), isFalse);
      expect(
        after.toPlainText(),
        contains('void'),
        reason: 'The cached tree must not outlive the text it was built from',
      );

      await _settle(wt, controller);
    });

    testWidgets('folding and unfolding invalidate', (wt) async {
      final (controller, context) = await _pump(wt);

      final unfolded = _span(controller, context);
      expect(identical(unfolded, _span(controller, context)), isTrue);

      controller.foldAt(0);

      final folded = _span(controller, context);
      expect(identical(unfolded, folded), isFalse);
      expect(
        folded.toPlainText(),
        isNot(contains('int a')),
        reason: 'A stale unfolded tree after a fold would render hidden code',
      );

      controller.unfoldAt(0);

      final refolded = _span(controller, context);
      expect(identical(folded, refolded), isFalse);
      expect(refolded.toPlainText(), contains('int a'));

      await _settle(wt, controller);
    });

    testWidgets('a different style invalidates', (wt) async {
      final (controller, context) = await _pump(wt);

      final normal = _span(controller, context);
      expect(identical(normal, _span(controller, context)), isTrue);

      final large = _span(
        controller,
        context,
        style: const TextStyle(fontSize: 40),
      );

      expect(identical(normal, large), isFalse);
      expect(
        _fingerprintOf(large).first.$2?.fontSize,
        40,
        reason: 'The style reaches the root span and must force a rebuild',
      );

      await _settle(wt, controller);
    });

    testWidgets('a hit happens with and without a CodeTheme', (wt) async {
      // The pair of cases that separate keying on the theme that is in scope
      // from keying on the theme the controller fabricates. The second one is
      // the trap: with no `CodeTheme` ancestor, `_getTheme` builds a fresh
      // `CodeThemeData` on every call and that class has no `==`, so a key
      // built from it never compares equal.
      final (noThemeController, noThemeContext) = await _pump(wt);
      expect(
        identical(
          _span(noThemeController, noThemeContext),
          _span(noThemeController, noThemeContext),
        ),
        isTrue,
        reason: 'A field with no CodeTheme must still cache',
      );

      final (themed, themedContext) = await _pump(wt, theme: _theme);
      expect(
        identical(_span(themed, themedContext), _span(themed, themedContext)),
        isTrue,
      );

      await _settle(wt, noThemeController);
      await _settle(wt, themed);
    });

    testWidgets('a theme swap invalidates', (wt) async {
      var theme = _theme;
      final controller = createController(_text);
      addTearDown(controller.dispose);

      Future<void> pump() async {
        focusNode = FocusNode();
        await wt.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CodeTheme(
                data: theme,
                child: CodeField(controller: controller, focusNode: focusNode),
              ),
            ),
          ),
        );
        focusNode.requestFocus();
      }

      await pump();
      final context = wt.element(find.byType(CodeField));

      final pink = _span(controller, context);
      expect(identical(pink, _span(controller, context)), isTrue);
      expect(
        _leavesOf(pink)
            .firstWhere((leaf) => leaf.text?.contains('void') ?? false)
            .style
            ?.color,
        const Color(0xFFE040FB),
      );

      theme = CodeThemeData(keywordStyle: const TextStyle(color: Colors.teal));
      await pump();

      final teal = _span(controller, context);
      expect(identical(pink, teal), isFalse);
      expect(
        _leavesOf(teal)
            .firstWhere((leaf) => leaf.text?.contains('void') ?? false)
            .style
            ?.color,
        Colors.teal,
        reason: 'A cached tree must not outlive the theme it was painted with',
      );

      await _settle(wt, controller);
    });

    testWidgets('the language can be dropped and the path is still cached', (
      wt,
    ) async {
      final (controller, context) = await _pump(wt, withLanguage: false);

      final first = _span(controller, context);
      expect(identical(first, _span(controller, context)), isTrue);

      controller.text = '${_text}void';

      final second = _span(controller, context);
      expect(identical(first, second), isFalse);
      expect(second.toPlainText(), contains('void'));

      expect(
        controller.language,
        isNull,
        reason: 'Without a language the controller returns a single flat span',
      );
      expect(second.children, isNull);

      await _settle(wt, controller);
    });

    testWidgets('dropping the language invalidates', (wt) async {
      final (controller, context) = await _pump(wt);

      final parsed = _span(controller, context);
      expect(identical(parsed, _span(controller, context)), isTrue);

      controller.language = null;

      final flat = _span(controller, context);
      expect(identical(parsed, flat), isFalse);
      expect(
        flat.children,
        isNull,
        reason:
            'A parsed tree must not outlive the language it was parsed with',
      );
      expect(flat.toPlainText(), parsed.toPlainText());

      await _settle(wt, controller);
    });

    testWidgets('an active search invalidates and follows navigation', (
      wt,
    ) async {
      final (controller, context) = await _pump(
        wt,
        text: 'int Aa = 1;\nint ab = 2;\n',
      );

      final plain = _span(controller, context);
      expect(identical(plain, _span(controller, context)), isTrue);

      controller.showSearch();
      controller.searchController.settingsController.value = _patternA;

      final searched = _span(controller, context);
      expect(identical(plain, searched), isFalse);
      expect(
        _leavesOf(
          searched,
        ).any((leaf) => leaf.style?.backgroundColor == matchBackgroundColor),
        isTrue,
        reason: 'The matches must actually be highlighted, not just changed',
      );

      final currentBeforeMove = _currentMatchTextOf(searched);
      controller.searchController.navigationController.moveNext();
      final moved = _span(controller, context);

      expect(identical(searched, moved), isFalse);
      expect(
        _currentMatchTextOf(moved),
        isNot(currentBeforeMove),
        reason:
            'The highlighted match is part of the tree, so moving it must '
            'produce a new tree',
      );

      await _settle(wt, controller);
    });

    testWidgets('closing the search invalidates', (wt) async {
      final (controller, context) = await _pump(wt);

      controller.showSearch();
      controller.searchController.settingsController.value = _patternA;
      final searched = _span(controller, context);
      expect(identical(searched, _span(controller, context)), isTrue);

      controller.searchController.settingsController.value =
          SearchSettings.empty;
      final closed = _span(controller, context);

      expect(identical(searched, closed), isFalse);
      expect(
        _leavesOf(
          closed,
        ).any((leaf) => leaf.style?.backgroundColor == matchBackgroundColor),
        isFalse,
      );

      await _settle(wt, controller);
    });

    testWidgets('a second pattern with the same current match invalidates', (
      wt,
    ) async {
      // The shape that separates the search half of the key from the navigation
      // half. `_patternA` and `_patternB` both leave the current match at index
      // 0, so `currentMatchIndex` is equal across the two calls and the match
      // set is the only component that can tell them apart. A pattern change
      // that moved the current match would invalidate through the navigation
      // half and hide the result half completely.
      final (controller, context) = await _pump(
        wt,
        text: 'int Aa = 1;\nint ab = 2;\n',
      );

      controller.showSearch();
      controller.searchController.settingsController.value = _patternA;

      final broad = _span(controller, context);
      expect(identical(broad, _span(controller, context)), isTrue);
      expect(_matchTextsOf(broad), 'Aaa');

      controller.searchController.settingsController.value = _patternB;

      final narrow = _span(controller, context);
      expect(identical(broad, narrow), isFalse);
      expect(
        _matchTextsOf(narrow),
        'Aa',
        reason: 'The cached tree must not outlive the pattern it was built for',
      );

      await _settle(wt, controller);
    });

    testWidgets('an active search does not accumulate leaves', (wt) async {
      final (controller, context) = await _pump(wt);

      controller.showSearch();
      controller.searchController.settingsController.value = _patternA;

      final first = _span(controller, context);
      final second = _span(controller, context);

      expect(
        identical(first, second),
        isTrue,
        reason: 'A cache hit must be a real hit, not a rebuild',
      );
      expect(
        _leavesOf(second).length,
        _leavesOf(first).length,
        reason:
            'The highlight builder appends to a list it never clears, so a '
            'builder reused for a second tree would double its leaves',
      );

      await _settle(wt, controller);
    });

    testWidgets('the composing path is not served from the cache', (wt) async {
      final (controller, context) = await _pump(wt);

      final plainSpan = TextEditingController()
        ..value = const TextEditingValue(
          text: 'int n;',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 4, end: 5),
        );
      addTearDown(plainSpan.dispose);

      controller.value = const TextEditingValue(
        text: 'int n;',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 4, end: 5),
      );

      final composing = controller.buildTextSpan(
        context: context,
        withComposing: true,
      );
      final again = controller.buildTextSpan(
        context: context,
        withComposing: true,
      );

      expect(identical(composing, again), isFalse);
      expect(
        composing.toPlainText(),
        plainSpan
            .buildTextSpan(context: context, withComposing: true)
            .toPlainText(),
        reason: 'While composing the span must delegate to the default',
      );

      controller.dismiss();
      await wt.pumpAndSettle();

      await _settle(wt, controller);
    });

    testWidgets('a hit is structurally what a rebuild produces', (wt) async {
      final (controller, context) = await _pump(wt);

      final cached = _span(controller, context);
      expect(identical(cached, _span(controller, context)), isTrue);

      // A second controller over the same document builds the same tree from
      // scratch, so this is a real construction to compare against rather than
      // a literal somebody has to keep in sync by hand.
      final twin = createController(_text);
      addTearDown(twin.dispose);
      final built = twin.buildTextSpan(
        context: context,
        style: const TextStyle(),
      );

      expect(
        _fingerprintOf(cached),
        _fingerprintOf(built),
        reason:
            'The cache may return an old object; it may not return a '
            'different one',
      );

      await _settle(wt, controller);
    });

    testWidgets('the cached path carries the fold marker', (wt) async {
      final (controller, context) = await _pump(wt);

      controller.foldAt(0);
      final folded = _span(controller, context);
      expect(identical(folded, _span(controller, context)), isTrue);

      expect(
        folded.toPlainText(),
        contains('…'),
        reason: 'The marker is part of the tree, so a cache hit keeps it',
      );

      await _settle(wt, controller);
    });
  });
}
