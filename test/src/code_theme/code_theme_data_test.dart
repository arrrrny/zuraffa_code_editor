import 'package:zuraffa_code_editor/src/code_theme/code_theme_data.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeThemeData', () {
    test('an empty instance has an empty styles map', () {
      final data = CodeThemeData();

      expect(data.styles, isEmpty);
      expect(data.hashCode, isA<int>());
    });

    test('every named style lands in the map under its own key', () {
      final data = CodeThemeData(
        classStyle: TextStyle(),
        commentStyle: TextStyle(),
        functionStyle: TextStyle(),
        keywordStyle: TextStyle(),
        paramsStyle: TextStyle(),
        quoteStyle: TextStyle(),
        titleStyle: TextStyle(),
        variableStyle: TextStyle(),
      );

      expect(data.styles.keys, {
        'class',
        'comment',
        'function',
        'keyword',
        'params',
        'quote',
        'title',
        'variable',
      });
    });

    test('a styles map given directly is used as is', () {
      const style = TextStyle();
      final data = CodeThemeData(styles: {'root': style});

      expect(data.styles['root'], same(style));
      expect(data.styles.keys, {'root'});
    });

    test('equality and hashCode follow the styles map', () {
      final data = CodeThemeData(styles: {'keyword': TextStyle()});

      expect(data.styles, <String, TextStyle>{'keyword': TextStyle()});
      expect(data, isNot(CodeThemeData()));
      expect(data, isNot(CodeThemeData(styles: {'quote': TextStyle()})));
    });
  });
}
