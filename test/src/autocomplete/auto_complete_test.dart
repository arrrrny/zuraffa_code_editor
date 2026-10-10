import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/autocomplete/auto_complete.dart';

/// The in-house autocompletion engine that replaced `autotrie` (#23).
///
/// `Autocompleter` only exercises `enter`, `enterList`, `suggest` and
/// `clearEntries`, so the rest of the ported surface has no caller inside the
/// package. These tests cover it, because it is now code this repository owns
/// and the coverage gate demands every line be reached.
void main() {
  AutoComplete engine([List<String> bank = const []]) =>
      AutoComplete(engine: SortEngine.entriesOnly(), bank: bank);

  group('AutoComplete construction', () {
    test('a bank is entered word by word', () {
      final ac = engine(['alpha', 'beta']);

      expect(ac.suggest('a'), ['alpha']);
      expect(ac.suggest('b'), ['beta']);
    });

    test('an empty bank leaves the engine empty', () {
      expect(engine().isEmpty, isTrue);
    });

    test('an empty string bank entry is kept', () {
      final ac = engine(['']);

      // The root carries no hit, so '' is not its own suggestion.
      expect(ac.suggest(''), isEmpty);
      expect(ac.suggest('x'), isEmpty);
    });
  });

  group('AutoComplete.enter', () {
    test('a repeated entry is promoted above a single one', () {
      final ac = engine();
      ac.enter('alpha');
      ac.enter('beta');
      ac.enter('alpha');

      expect(ac.suggest(''), ['alpha', 'beta']);
    });

    test('a tie keeps trie order, not recency', () {
      final ac = engine();
      ac.enter('alpha');
      ac.enter('beta');
      ac.enter('gamma');
      ac.enter('beta');

      // beta has 2 hits and comes first. alpha and gamma tie at 1, and the only
      // sort engine this port carries scores by entry count alone, so the tie
      // keeps trie order — the order the words were first entered.
      expect(ac.suggest(''), ['beta', 'alpha', 'gamma']);
    });
  });

  group('AutoComplete.enterList', () {
    test('enters every entry', () {
      final ac = engine();
      ac.enterList(['alpha', 'beta', 'gamma']);

      expect(ac.suggest(''), ['alpha', 'beta', 'gamma']);
    });

    test('counts repeats across calls', () {
      final ac = engine();
      ac.enterList(['alpha', 'alpha', 'beta']);

      expect(ac.suggest(''), ['alpha', 'beta']);
    });
  });

  group('AutoComplete.suggest', () {
    test('an unmatched prefix suggests nothing', () {
      expect(engine(['alpha']).suggest('z'), isEmpty);
    });

    test('a complete word is its own suggestion', () {
      final ac = engine(['alpha']);

      expect(ac.suggest('alpha'), ['alpha']);
    });

    test('an empty prefix suggests everything', () {
      expect(engine(['alpha', 'beta']).suggest(''), ['alpha', 'beta']);
    });
  });

  group('AutoComplete.allEntries', () {
    test('lists every entered word', () {
      expect(engine(['alpha', 'beta']).allEntries, ['alpha', 'beta']);
    });

    test('an empty engine has no entries', () {
      expect(engine().allEntries, isEmpty);
    });

    test('a word is listed once however often it was entered', () {
      final ac = engine();
      ac.enterList(['alpha', 'alpha', 'alpha']);

      expect(ac.allEntries, ['alpha']);
    });
  });

  group('AutoComplete.isEmpty', () {
    test('is false once an entry is entered', () {
      final ac = engine();
      ac.enter('alpha');

      expect(ac.isEmpty, isFalse);
    });
  });

  group('AutoComplete.contains', () {
    test('finds an entered word', () {
      expect(engine(['alpha']).contains('alpha'), isTrue);
    });

    test('rejects a word that was never entered', () {
      expect(engine(['alpha']).contains('beta'), isFalse);
    });

    test('rejects a prefix of an entered word', () {
      // `contains` reports entered words, not the characters on the way to
      // them, so a strict prefix of a word is not contained.
      expect(engine(['alpha']).contains('alph'), isFalse);
    });

    test('rejects a prefix that was never entered', () {
      expect(engine(['alpha']).contains('alpz'), isFalse);
    });
  });

  group('AutoComplete.delete', () {
    test('removing an entry stops it being suggested', () {
      final ac = engine(['alpha', 'beta']);
      ac.delete('alpha');

      expect(ac.suggest(''), ['beta']);
      expect(ac.contains('alpha'), isFalse);
    });

    test('a removed entry can be entered again', () {
      final ac = engine(['alpha']);
      ac.delete('alpha');
      ac.enter('alpha');

      expect(ac.suggest(''), ['alpha']);
    });

    test('removing a shared prefix keeps the longer word', () {
      final ac = engine(['alpha', 'alphabet']);
      ac.delete('alpha');

      expect(ac.suggest(''), ['alphabet']);
      expect(ac.contains('alpha'), isFalse);
    });

    test('removing the longer word keeps the shared prefix', () {
      final ac = engine(['alpha', 'alphabet']);
      ac.delete('alphabet');

      expect(ac.suggest(''), ['alpha']);
    });

    test('the survivor of a shared-prefix delete is deletable too', () {
      final ac = engine(['alpha', 'alphabet']);
      ac.delete('alpha');
      ac.delete('alphabet');

      // The first delete clears the hit on the shared terminal node; only a
      // `_delete` that does that can leave the engine empty here.
      expect(ac.suggest(''), isEmpty);
      expect(ac.isEmpty, isTrue);
    });

    test('removing one of two sharing a prefix keeps the other', () {
      final ac = engine(['alpha', 'alpine']);
      ac.delete('alpha');

      expect(ac.suggest(''), ['alpine']);
    });

    test('deleting from an empty engine does nothing', () {
      final ac = engine();
      ac.delete('alpha');

      expect(ac.isEmpty, isTrue);
    });

    test('deleting a word that is not there does nothing', () {
      final ac = engine(['alpha']);
      ac.delete('beta');

      expect(ac.suggest(''), ['alpha']);
    });
  });

  group('AutoComplete.clearEntries', () {
    test('empties the engine', () {
      final ac = engine(['alpha']);
      ac.clearEntries();

      expect(ac.isEmpty, isTrue);
      expect(ac.suggest(''), isEmpty);
    });

    test('the engine is usable again afterwards', () {
      final ac = engine(['alpha']);
      ac.clearEntries();
      ac.enter('beta');

      expect(ac.suggest('b'), ['beta']);
    });
  });

  group('SortEngine', () {
    test('entriesOnly scores by the entry count alone', () {
      final engine = SortEngine.entriesOnly();

      expect(
        engine.scoreFunc(SortValue(0, 3)) >
            engine.scoreFunc(SortValue(1000, 2)),
        isTrue,
      );
      expect(
        engine.scoreFunc(SortValue(0, 2)),
        engine.scoreFunc(SortValue(9000, 2)),
      );
    });
  });

  group('SortValue', () {
    test('carries the recency and the entry count', () {
      final value = SortValue(1234, 5);

      expect(value.lastInsert, 1234);
      expect(value.numEntries, 5);
    });
  });

  group('TrieNode', () {
    test('compares by value only', () {
      expect(TrieNode('a', false), TrieNode('a', true));
      expect(TrieNode('a', false), isNot(TrieNode('b', false)));
    });

    test('hashCode agrees with the equality it overrides', () {
      expect(TrieNode('a', false).hashCode, TrieNode('a', true).hashCode);
      expect(
        TrieNode('a', false).hashCode,
        isNot(TrieNode('b', false).hashCode),
      );

      // The pairing is what makes a node usable as a key.
      final set = <TrieNode>{TrieNode('a', false), TrieNode('a', true)};
      expect(set.length, 1);
    });
  });

  group('TrieString', () {
    test('renders its value, hits and recency', () {
      expect(TrieString('alpha', 2, 7).toString(), 'alpha | 2 | 7');
    });
  });
}
