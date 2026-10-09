import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/code/code_edit_result.dart';

void main() {
  const editResult = CodeEditResult(
    fullTextAfter: 'int a = 1;',
    linesChanged: TextRange(start: 0, end: 1),
  );

  group('CodeEditResult', () {
    test('toString renders both fields', () {
      expect(
        editResult.toString(),
        'fullTextAfter: int a = 1;, linesChanged: TextRange(start: 0, end: 1)',
      );
    });

    test('equality compares fullTextAfter and linesChanged', () {
      expect(
        editResult,
        const CodeEditResult(
          fullTextAfter: 'int a = 1;',
          linesChanged: TextRange(start: 0, end: 1),
        ),
      );
      expect(
        editResult,
        isNot(
          const CodeEditResult(
            fullTextAfter: 'int a = 2;',
            linesChanged: TextRange(start: 0, end: 1),
          ),
        ),
      );
      expect(
        editResult,
        isNot(
          const CodeEditResult(
            fullTextAfter: 'int a = 1;',
            linesChanged: TextRange(start: 0, end: 2),
          ),
        ),
      );
      expect(editResult, isNot(equals('not a CodeEditResult')));
    });

    test('equal instances share a hashCode', () {
      expect(
        editResult.hashCode,
        const CodeEditResult(
          fullTextAfter: 'int a = 1;',
          linesChanged: TextRange(start: 0, end: 1),
        ).hashCode,
      );
    });
  });
}
