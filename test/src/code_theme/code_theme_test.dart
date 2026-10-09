import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code_theme/code_theme.dart';
import 'package:zuraffa_code_editor/src/code_theme/code_theme_data.dart';

void main() {
  group('CodeTheme.of', () {
    testWidgets('returns the data from the nearest ancestor', (tester) async {
      final data = CodeThemeData(styles: const {'keyword': TextStyle()});

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CodeTheme(
            data: data,
            child: Builder(
              builder: (context) {
                expect(CodeTheme.of(context), same(data));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('returns null without an ancestor', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              expect(CodeTheme.of(context), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('CodeTheme.updateShouldNotify', () {
    test('is false when the data is the same instance', () {
      final data = CodeThemeData(styles: const {'keyword': TextStyle()});
      final widget = CodeTheme(data: data, child: const SizedBox());
      final oldWidget = CodeTheme(data: data, child: const SizedBox());

      expect(widget.updateShouldNotify(oldWidget), isFalse);
    });

    test('is true when the data differs', () {
      final oldData = CodeThemeData(styles: const {'keyword': TextStyle()});
      final newData = CodeThemeData(styles: const {'comment': TextStyle()});
      final widget = CodeTheme(data: newData, child: const SizedBox());
      final oldWidget = CodeTheme(data: oldData, child: const SizedBox());

      expect(widget.updateShouldNotify(oldWidget), isTrue);
    });
  });
}
