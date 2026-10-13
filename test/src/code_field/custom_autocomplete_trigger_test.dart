/// #88 — an autocomplete callback driven by custom triggers.
///
/// Upstream `akvelon/flutter-code-editor#220`: the reporter wants completion
/// after ` >> `. Today `CodeController.generateSuggestions()` asks
/// `CodeController.autocompleter` for words matching `value.wordToCursor`, and
/// `wordToCursor` is the word at the caret split on `RegExps.wordSplit`, so a
/// trigger built from spaces and punctuation can never produce a prefix. The
/// only workaround the reporter found was subclassing `CodeController` and
/// overriding `generateSuggestions`.
///
/// Every behaviour here is driven through a real `CodeField`, so the path under
/// test is the one a keystroke takes: `set value` → `generateSuggestions` →
/// `popupController.show`.
library;

import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

/// A trigger whose callback reports exactly what it was asked, so a test can
/// assert on the prefix without owning the suggestion list.
final _askedPrefixes = <String>[];

CustomAutocompleteTrigger _triggerThatReports(
  String trigger, [
  List<String> Function(String prefix)? suggestions,
]) {
  return CustomAutocompleteTrigger(
    trigger: trigger,
    getSuggestions: (prefix) {
      _askedPrefixes.add(prefix);
      return (suggestions ?? (_) => <String>[])(prefix);
    },
  );
}

void main() {
  setUp(_askedPrefixes.clear);

  Future<CodeController> pumpEditor(WidgetTester wt, {String text = ''}) async {
    final controller = await pumpController(wt, text);
    controller.selection = TextSelection.collapsed(offset: text.length);
    await wt.pumpAndSettle();
    return controller;
  }

  Future<void> type(WidgetTester wt, CodeController c, String text) async {
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    await wt.pumpAndSettle();
  }

  group('A registered trigger shows its own suggestions (#88)', () {
    testWidgets('when the trigger has just been typed', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha', 'beta']),
      ];

      await type(wt, controller, ' >> ');

      expect(controller.popupController.shouldShow, isTrue);
      expect(controller.popupController.suggestions, ['alpha', 'beta']);
      expect(
        find.text('alpha'),
        findsOneWidget,
        reason: 'the popup is built by the field, not only by the controller',
      );
      expect(
        _askedPrefixes,
        const [''],
        reason:
            'the trigger was just typed, so the prefix handed over is empty',
      );
    });

    testWidgets('from an asynchronous callback', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        CustomAutocompleteTrigger(
          trigger: ' >> ',
          getSuggestions: (_) async => ['alpha'],
        ),
      ];

      await type(wt, controller, ' >> ');

      expect(controller.popupController.suggestions, ['alpha']);
    });
  });

  group('The callback narrows as more of the trigger follows (#88)', () {
    final dictionary = ['alpha', 'alps', 'beta', 'foxtrot'];

    testWidgets('one keystroke at a time', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (prefix) {
          return dictionary
              .where((word) => word.startsWith(prefix))
              .toList(growable: false);
        }),
      ];

      await type(wt, controller, ' >> ');
      expect(controller.popupController.suggestions, dictionary);

      await type(wt, controller, ' >> f');
      expect(controller.popupController.suggestions, ['foxtrot']);

      await type(wt, controller, ' >> fo');
      expect(controller.popupController.suggestions, ['foxtrot']);

      await type(wt, controller, ' >> fox');
      expect(controller.popupController.suggestions, ['foxtrot']);

      expect(_askedPrefixes, const ['', 'f', 'fo', 'fox']);
    });

    testWidgets('and an empty result hides the popup again', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (prefix) {
          return dictionary
              .where((word) => word.startsWith(prefix))
              .toList(growable: false);
        }),
      ];

      await type(wt, controller, ' >> f');
      expect(controller.popupController.shouldShow, isTrue);

      await type(wt, controller, ' >> z');
      expect(controller.popupController.shouldShow, isFalse);
      expect(find.text('foxtrot'), findsNothing);
    });

    testWidgets('while the trigger is still being typed nothing is armed', (
      wt,
    ) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha']),
      ];

      await type(wt, controller, ' > ');
      expect(controller.popupController.shouldShow, isFalse);
      expect(_askedPrefixes, isEmpty);
    });
  });

  group('Several triggers register side by side (#88)', () {
    testWidgets('each arms on its own string', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['fromDouble']),
        _triggerThatReports('@', (_) => ['annotation']),
      ];

      await type(wt, controller, 'code @ann');

      expect(controller.popupController.suggestions, ['annotation']);
      expect(_askedPrefixes, const ['ann']);
    });

    testWidgets('the first registered wins when both could match', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports('>>', (_) => ['bareArrows']),
        _triggerThatReports(' >> ', (_) => ['spacedArrows']),
      ];

      await type(wt, controller, 'code >>');

      expect(controller.popupController.suggestions, ['bareArrows']);
      expect(_askedPrefixes, const ['']);
    });
  });

  group('The last occurrence before the caret is the one that arms (#88)', () {
    testWidgets('so a prefix may contain the trigger text', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha']),
      ];

      await type(wt, controller, 'a >> b >> c');

      expect(controller.popupController.suggestions, ['alpha']);
      expect(_askedPrefixes, const ['c']);
    });

    testWidgets('and an earlier line does not arm a caret below it', (
      wt,
    ) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha']),
      ];

      await type(wt, controller, 'x >> y\nsomeOtherLine');

      expect(controller.popupController.shouldShow, isFalse);
      expect(_askedPrefixes, isEmpty);
    });
  });

  group('The keyword completer survives (#88)', () {
    /// `createController` defaults to Java, whose keyword list holds `const`
    /// and `continue` — a prefix that really does produce a suggestion, so the
    /// popup's `suggestions` list gets initialized.
    testWidgets('unchanged with no trigger registered', (wt) async {
      final controller = await pumpController(wt, 'c');

      controller.value = TextEditingValue(
        text: 'co',
        selection: const TextSelection.collapsed(offset: 2),
      );
      await wt.pumpAndSettle();

      expect(controller.popupController.suggestions, [
        'const',
        'continue',
      ], reason: 'the keyword path still runs entirely as it did before #88');
    });

    testWidgets('an empty list is a no-op, not a regression', (wt) async {
      final controller = await pumpController(wt, 'c');
      controller.customAutocompleteTriggers = const [];

      controller.value = TextEditingValue(
        text: 'co',
        selection: const TextSelection.collapsed(offset: 2),
      );
      await wt.pumpAndSettle();

      expect(controller.popupController.suggestions, ['const', 'continue']);
    });

    testWidgets('an armed trigger owns the list instead', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha', 'beta']),
      ];

      await type(wt, controller, ' >> co');

      expect(controller.popupController.suggestions, ['alpha', 'beta']);
      expect(
        controller.popupController.suggestions,
        isNot(anyOf(contains('const'), contains('continue'))),
        reason: "the keyword words do not leak into a custom trigger's list",
      );
    });
  });

  group('Committing a suggestion from a custom trigger (#88)', () {
    testWidgets('inserts the word when the prefix is empty', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha', 'beta']),
      ];

      await type(wt, controller, ' >> ');

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pumpAndSettle();

      expect(controller.text, ' >> alpha ');
      expect(controller.popupController.shouldShow, isFalse);
    });

    testWidgets('replaces the prefix when there is one', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha', 'beta']),
      ];

      await type(wt, controller, ' >> be');

      await wt.tap(find.text('beta'));
      await wt.pumpAndSettle();

      expect(controller.text, ' >> beta ');
    });

    testWidgets('does not re-arm the trigger that produced it', (wt) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha', 'beta']),
      ];

      await type(wt, controller, ' >> ');
      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pumpAndSettle();

      expect(controller.popupController.shouldShow, isFalse);
      expect(
        _askedPrefixes,
        const [''],
        reason:
            "the commit's own write is not allowed to ask the trigger again",
      );
    });

    testWidgets('the one-shot is spent, so the next keystroke arms', (
      wt,
    ) async {
      final controller = await pumpEditor(wt);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha']),
      ];

      await type(wt, controller, ' >> ');
      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pumpAndSettle();

      // Moving the caret hides the popup, and the one-shot was already spent by
      // the commit's own write — so this keystroke is a plain re-arm.
      controller.selection = const TextSelection.collapsed(offset: 3);
      await wt.pumpAndSettle();

      await type(wt, controller, ' >> a');

      expect(controller.popupController.shouldShow, isTrue);
      expect(_askedPrefixes, const ['', 'a']);
    });
  });

  group('No caret (#88)', () {
    testWidgets('a caret of -1 arms nothing and does not throw', (wt) async {
      // No widget: the field's first value round-trip normalises an invalid
      // selection back to a real offset, so only a controller the framework has
      // never touched still carries one. `generateSuggestions` is public API a
      // host may call in exactly that state.
      final controller = createController('');
      addTearDown(controller.dispose);
      controller.customAutocompleteTriggers = [
        _triggerThatReports(' >> ', (_) => ['alpha']),
      ];

      expect(
        controller.selection.start,
        -1,
        reason: 'the controller starts with an invalid selection',
      );
      await controller.generateSuggestions();

      // And the start of the document, where the line-start scan has no newline
      // to step back over.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await controller.generateSuggestions();

      expect(_askedPrefixes, isEmpty);
    });
  });
}
