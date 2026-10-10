import 'package:flutter/material.dart';
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/src/gutter/fold_toggle.dart';
import 'package:zuraffa_code_editor/src/gutter/gutter.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the upstream issue
/// <https://github.com/akvelon/flutter-code-editor/issues/213>:
///
/// "Foldable block doesn't fold correctly when there is another foldable
/// block at the end of the first."
///
/// The reporter's code has `}void main(){` on one line — the closing brace of
/// `factorial` and the opening brace of `main` share a line. Folding
/// `factorial` made the start of the following block (`}void main(){`)
/// disappear: no row in the gutter, no fold toggle, and its line number gone.
void main() {
  // 0-based lines:
  //  0  // Calculates the factorial of the number.
  //  1  // The number must be >= 0.
  //  2  int factorial(int n){
  //  3    if(n == 0){
  //  4      return 0;
  //  5    }
  //  6
  //  7    return n * factorial(n - 1);
  //  8  }void main(){
  //  9    int num = 5;
  // 10    print('Factorial of $num is ${factorial(num)}');
  // 11  }
  const source =
      '// Calculates the factorial of the number.\n'
      '// The number must be >= 0.\n'
      'int factorial(int n){\n'
      '  if(n == 0){\n'
      '    return 0;\n'
      '  }\n'
      '\n'
      '  return n * factorial(n - 1);\n'
      '}void main(){\n'
      '  int num = 5;\n'
      '  print(\'Factorial of \$num is \${factorial(num)}\');\n'
      '}\n';

  const foldedFactorialText = '''
// Calculates the factorial of the number.
// The number must be >= 0.
int factorial(int n){
}void main(){
  int num = 5;
  print('Factorial of \$num is \${factorial(num)}');
}
''';

  const foldedMainText = '''
// Calculates the factorial of the number.
// The number must be >= 0.
int factorial(int n){
  if(n == 0){
    return 0;
  }

  return n * factorial(n - 1);
}void main(){}
''';
  CodeController createController() =>
      CodeController(text: source, language: java);

  group('A block that follows another one on its closing line.', () {
    test('is a foldable block of its own', () {
      final code = createController().code;

      expect(
        code.foldableBlocks.map((b) => '${b.firstLine}..${b.lastLine}'),
        containsAllInOrder(<String>['0..1', '2..8', '3..5', '8..11']),
      );
    });

    test('keeps its start visible when the block above it is folded', () {
      final controller = createController();

      controller.foldAt(2); // `int factorial(int n){`

      expect(controller.text, foldedFactorialText);
      expect(
        controller.code.hiddenLineRanges.visibleLineNumbers.toList(),
        <int>[0, 1, 2, 8, 9, 10, 11, 12],
      );

      // The following block's first line keeps a row of its own.
      expect(controller.code.hiddenLineRanges.cutLineIndexIfVisible(8), 3);
      expect(
        controller.code.hiddenLineRanges.cutLineIndexIfVisible(8),
        isNotNull,
        reason: 'the start of the next block must not become hidden',
      );
    });

    test('keeps the gutter and the editor in agreement on the row count', () {
      final controller = createController();

      controller.foldAt(2);

      // Every visible line has a gutter row, and every row of the visible
      // text has a line number. A mismatch here is what makes code scroll
      // out of sync with the line numbers.
      expect(
        controller.code.hiddenLineRanges.visibleLineNumbers.length,
        controller.code.visibleText.split('\n').length,
      );
    });

    test('can be folded on its own', () {
      final controller = createController();

      controller.foldAt(8); // `}void main(){`

      expect(controller.text, foldedMainText);
      expect(
        controller.code.hiddenLineRanges.cutLineIndexIfVisible(8),
        isNotNull,
      );
    });

    test('folding the outer block swallows the inner one, losslessly', () {
      final controller = createController();

      controller.foldAt(2); // `int factorial(int n){` folds 2..8
      controller.foldAt(3); // `  if(n == 0){` folds 3..5

      expect(controller.text, foldedFactorialText);
      expect(controller.code.text, source, reason: 'the full text survives');

      controller.unfoldAt(3);
      controller.unfoldAt(2);
      expect(controller.text, source);
      expect(controller.code.foldedBlocks, isEmpty);
    });
  });

  group('The gutter still offers a fold toggle for the following block.', () {
    testWidgets('The toggle for `main` is rendered', (wt) async {
      wt.view.physicalSize = const Size(800, 1000);
      wt.view.devicePixelRatio = 1.0;
      addTearDown(wt.view.reset);

      final controller = createController();
      addTearDown(controller.dispose);

      controller.foldAt(2); // `int factorial(int n){`
      await wt.pump();

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              controller: controller,
              gutterStyle: const GutterStyle(showFoldingHandles: true),
            ),
          ),
        ),
      );
      await wt.pumpAndSettle();

      expect(find.byType(GutterWidget), findsOneWidget);

      // The comment block, the folded `factorial` block and the `main` block
      // that starts on the closing line. The `if` block is folded away with
      // its parent, so it has no row to hang a toggle on.
      expect(find.byType(FoldToggle), findsNWidgets(3));
    });
  });
}
