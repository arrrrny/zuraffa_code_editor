import 'package:zuraffa_code_editor/src/autocomplete/autocompleter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/java.dart';

import '../common/lorem_ipsum.dart';

const _edgeText = r'''
'Single_quotes1 single_quotes2' 'single_quotes3'
"double_quotes1 double_quotes2" "double_quotes3"
~tilde1 tilde2~ ~tilde3~
!bang1 bang2! !bang3!
@at1 at2@ @at3@
#number1 number2# #number3#
$dollar1 dollar2$ $dollar3$
%percent1 percent2% %percent3%
^caret1 caret2^ ^caret3^
&and1 and2& &and3&
*star1 star2* *star3*
(open_parenthesis1 open_parenthesis2( (open_parenthesis3(
)close_parenthesis1 close_parenthesis2) )close_parenthesis3)
-dash1 dash2- -dash3-
+plus1 plus2+ +plus3+
=equals1 equals2= =equals3=
/slash1 slash2/ /slash3/
\backslash1 backslash2\ \backslash3\
Ъunicode1 unicode2Ъ Ъunicode3Ъ
''';

void main() {
  group('Autocompleter', () {
    test('Mutable mode, keywords from mode, sorted ascending', () async {
      final ac = Autocompleter();

      final initialResults = await ac.getSuggestions('f');
      ac.mode = java;
      final javaResults = await ac.getSuggestions('f');
      ac.mode = dart;
      final dartResults = await ac.getSuggestions('f');
      ac.mode = null;
      final nullResults = await ac.getSuggestions('f');

      expect(initialResults, const []);
      expect(javaResults, ['false', 'final', 'finally', 'float', 'for']);
      expect(dartResults, [
        'factory',
        'false',
        'final',
        'finally',
        'for',
        //'Function', // https://github.com/AKushWarrior/autotrie/issues/8
      ]);
      expect(nullResults, const []);
    });

    test('Shows words from text', () async {
      final ac = Autocompleter();

      ac.setText(Object, loremIpsum);
      final singleResults = await ac.getSuggestions('s');
      expect(singleResults, ['sed', 'sint', 'sit', 'sunt']);

      ac.setText('2', _edgeText);
      final bothResults = await ac.getSuggestions('s');

      expect(bothResults, [
        'sed',
        //'Single_quotes1', // https://github.com/AKushWarrior/autotrie/issues/8
        'single_quotes2',
        'single_quotes3',
        'sint',
        'sit',
        'slash1',
        'slash2',
        'slash3',
        'star1',
        'star2',
        'star3',
        'sunt',
      ]);

      ac.setText('2', null);
      final singleResults2 = await ac.getSuggestions('s');
      expect(singleResults2, singleResults);

      ac.setText('2', _edgeText);
      final bothResults2 = await ac.getSuggestions('s');
      expect(bothResults2, bothResults);
    });

    test('Words added by typing match a fresh index', () async {
      final typed = Autocompleter();
      typed.setText('key', 'alpha beta');
      typed.setText('key', 'alpha beta gamma');

      final fresh = Autocompleter()..setText('key', 'alpha beta gamma');

      expect(await typed.getSuggestions(''), await fresh.getSuggestions(''));
    });

    test(
      'Drops a word that disappears, and one that prefixes another',
      () async {
        final wholeWordGone = Autocompleter();
        wholeWordGone.setText('key', 'foo foobar');
        wholeWordGone.setText('key', 'foo');

        expect(await wholeWordGone.getSuggestions('foobar'), const []);

        final prefixGone = Autocompleter();
        prefixGone.setText('key', 'foo foobar');
        prefixGone.setText('key', 'foobar');

        expect(await prefixGone.getSuggestions('foo'), const ['foobar']);
      },
    );

    test('Shows custom words', () async {
      final ac = Autocompleter();
      ac.setCustomWords(['Lorem', 'ipsum', 'word3', 'word4']);

      final results = await ac.getSuggestions('word');

      expect(results, ['word3', 'word4']);
    });

    test('Applies the blacklist', () async {
      final obj = Autocompleter();
      obj.mode = java;

      obj.blacklist = ['Finally'];
      final wrongCaseResults = await obj.getSuggestions('f');
      obj.blacklist = ['finally'];
      final results = await obj.getSuggestions('f');

      expect(wrongCaseResults, ['false', 'final', 'finally', 'float', 'for']);
      expect(results, ['false', 'final', 'float', 'for']);
    });

    test('Reports the blacklist back as a list', () {
      final obj = Autocompleter();

      expect(obj.blacklist, isEmpty);

      obj.blacklist = ['a', 'b'];
      expect(obj.blacklist, ['a', 'b']);
    });

    test('Rejects a mode whose keywords are neither a String nor a Map', () {
      final obj = Autocompleter();

      expect(
        () => obj.mode = Mode(keywords: 42),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unknown keywords type'),
          ),
        ),
      );
    });
  });
}
