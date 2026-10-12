// ignore_for_file: avoid_private_typedef_functions

import 'package:zuraffa_code_editor/src/folding/invalid_foldable_block.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/typescript.dart';

import 'test_executor.dart';

typedef _Tester = HighlightParserTestExecutor;

void main() {
  group('HighlightFoldableBlockParser for JavaScript.', () {
    test('Empty file.', () {
      _Tester.parseAndCheck(mode: javascript, code: '', expected: []);
    });

    test('Multiline named import keeps its braces fold.', () {
      const code = '''
import {
  foo,
  bar
} from 'module';''';
      const expected = [FB(firstLine: 0, lastLine: 3, type: FBT.braces)];
      _Tester.parseAndCheck(mode: javascript, code: code, expected: expected);
    });

    test('Multiline named import with a rename keeps its braces fold.', () {
      const code = '''
import {
  foo as bar,
  baz
} from 'module';''';
      const expected = [FB(firstLine: 0, lastLine: 3, type: FBT.braces)];
      _Tester.parseAndCheck(mode: javascript, code: code, expected: expected);
    });

    test('Single-line named import does not fold.', () {
      const code = '''
import { foo, bar } from 'module';''';
      _Tester.parseAndCheck(mode: javascript, code: code, expected: []);
    });

    test('An unclosed import brace does not swallow the rest of the file.', () {
      const code = '''
import {
const x = 1;
function foo() {
}''';
      const expected = [FB(firstLine: 2, lastLine: 3, type: FBT.braces)];
      final expectedInvalid = [
        InvalidFoldableBlock(startLine: 0, type: FBT.braces),
      ];
      _Tester.parseAndCheck(
        mode: javascript,
        code: code,
        expected: expected,
        invalid: expectedInvalid,
      );
    });
  });

  group('HighlightFoldableBlockParser for TypeScript.', () {
    test('Empty file.', () {
      _Tester.parseAndCheck(mode: typescript, code: '', expected: []);
    });

    test(
      'Multiline named import with a type member keeps its braces fold.',
      () {
        const code = '''
import {
  type Foo,
  Bar
} from 'module';''';
        const expected = [FB(firstLine: 0, lastLine: 3, type: FBT.braces)];
        _Tester.parseAndCheck(mode: typescript, code: code, expected: expected);
      },
    );
  });
}
