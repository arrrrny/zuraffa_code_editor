/// In-house autocompletion engine.
///
/// Replaces the `autotrie` package, which this package used before #23.
/// `autotrie` imports `dart:io` in its only entry point, so anything that
/// reached the autocompleter failed to compile for the web. The two
/// file-persistence methods that need it are not used here, so they are
/// dropped along with the Hive integration; only the in-memory surface is
/// ported, which is what `Autocompleter` consumes.
library;

class AutoComplete {
  final _TrieSearchTree _tree;

  /// Constructs an instance of `AutoComplete`.
  ///
  /// This uses [engine] to sort the results of autocompletion.
  ///
  /// If you pass a [bank] parameter, the engine will have all the Strings in
  /// bank as search results.
  ///
  /// If you enter a word multiple times, it will be prioritized in the search
  /// results, since search results are sorted by number of times entered.
  ///
  /// Ties keep trie order, which is the order the words were first entered:
  /// the only sort engine this port carries scores by entry count alone.
  AutoComplete({required SortEngine engine, List<String>? bank})
    : _tree = _TrieSearchTree(engine.scoreFunc) {
    bank ??= <String>[];
    for (var x in bank) {
      enter(x);
    }
  }

  /// Add an entry to the engine.
  ///
  /// The engine will now include `entry' as a search result. If you enter a word
  /// multiple times, it will be prioritized in the search results, since search
  /// results are sorted by number of times entered.
  void enter(String entry) {
    _tree.addWord(entry);
  }

  /// Add multiple entries to the engine.
  ///
  /// The engine will now include the contents of `entries` as a search result.
  /// If you enter a word multiple times, it will be prioritized in the search
  /// results, since search results are sorted by number of times entered.
  void enterList(List<String> entries) {
    for (var x in entries) {
      enter(x);
    }
  }

  /// Clear all the entries. The engine is now blank.
  void clearEntries() {
    _tree.root = TrieNode('', false);
  }

  /// Get all the entries in a list.
  ///
  /// This is NOT sorted. Use [suggest('')] to get all results, sorted.
  Iterable<String> get allEntries => _tree.all.map((e) => e.value);

  /// Suggest entries based on the beginning of the string.
  ///
  /// This method returns a `List<String>`, which contains the suggestions
  /// (entries).
  /// These suggestions are ordered by the number of times the suggestion has been
  /// entered.
  List<String> suggest(String prefix) {
    return _tree.suggestions(prefix);
  }

  /// Returns true if this engine has no entries.
  bool get isEmpty => _tree.root.children.isEmpty;

  /// Returns true if `entry` was entered, not merely that the characters on
  /// the way to it exist. A prefix of an entered word is therefore not
  /// contained, and neither is a word that was already [delete]d.
  bool contains(String entry) => _tree.search(entry);

  /// Deletes `entry` from the engine if it exists.
  ///
  /// If `entry` is not in the engine, it will do nothing.
  void delete(String entry) => _tree.remove(entry);
}

/// Sorts suggestions by how many times each entry was entered.
class SortEngine {
  late double Function(SortValue element) scoreFunc;

  SortEngine.entriesOnly() {
    scoreFunc = (SortValue a) => a.numEntries.toDouble();
  }
}

class SortValue {
  final int lastInsert;
  final int numEntries;

  SortValue(this.lastInsert, this.numEntries);
}

class _TrieSearchTree {
  TrieNode root;
  double Function(SortValue e) sort;

  _TrieSearchTree(this.sort) : root = TrieNode('', false) {
    root.children = <TrieNode>[];
  }

  void addWord(String word) {
    var base = root;

    //Iterate through string and add/progress through nodes.
    for (var i = 0; i < word.length; i++) {
      var x = TrieNode(word[i], false);
      if (!base.children.contains(x)) {
        // x is added to base.children
        base.children.add(x);
      } else {
        // x points to base.children version
        x = base.children.where((e) => e == x).first;
      }
      if (i == word.length - 1) {
        x.lastInsert = DateTime.now().millisecondsSinceEpoch;
        x.hits++;
      }
      base = x;
    }
  }

  List<TrieString> get all {
    var base = root;
    var returner = <TrieString>[];
    _suggestRec(base, '', returner);
    return returner;
  }

  List<String> suggestions(String prefix) {
    var base = root;
    for (var i = 0; i < prefix.length; i++) {
      var x = TrieNode(prefix[i], false);
      if (base.children.contains(x)) {
        base = base.children[base.children.indexOf(x)];
      } else {
        return [];
      }
    }
    var returner = <TrieString>[];
    _suggestRec(base, prefix, returner);

    returner.sort((TrieString a, TrieString b) {
      var sortA = sort(SortValue(a.lastInsert, a.hits));
      var sortB = sort(SortValue(b.lastInsert, b.hits));

      if (sortA < sortB) {
        return 1;
      } else if (sortA == sortB) {
        return 0;
      } else {
        return -1;
      }
    });
    return returner.map((e) => e.value).toList();
  }

  void _suggestRec(TrieNode node, String word, List<TrieString> returner) {
    if (node.hits > 0) {
      returner.add(TrieString(word, node.hits, node.lastInsert));
    }
    for (var n in node.children) {
      _suggestRec(n, word + n.value, returner);
    }
  }

  bool search(String word) {
    var base = root;
    for (var i = 0; i < word.length; i++) {
      var x = TrieNode(word[i], false);
      if (!base.children.contains(x)) return false;
      base = base.children[base.children.indexOf(x)];
    }
    return base.hits > 0;
  }

  void remove(String word) {
    if (root.children.isEmpty) {
      return;
    } else if (!search(word)) {
      return;
    }
    _delete(root, word, 0);
  }

  bool _delete(TrieNode cur, String word, int index) {
    if (index == word.length) {
      // Drop the hit first. `autotrie` only pruned childless nodes here, so a
      // word sharing its prefix with a longer one kept its hit and could never
      // be removed.
      cur.hits = 0;
      return cur.children.isEmpty;
    }
    var ch = word[index];
    var next = cur
        .children[cur.children.indexOf(TrieNode(ch, index == word.length - 1))];
    var shouldDeleteNode = _delete(next, word, index + 1) && next.hits == 0;

    if (shouldDeleteNode) {
      cur.children.remove(next);
      return cur.children.isEmpty;
    }
    return false;
  }
}

class TrieString {
  String value;
  int hits;
  int lastInsert;

  TrieString(this.value, this.hits, this.lastInsert);

  @override
  String toString() {
    return '$value | $hits | $lastInsert';
  }
}

class TrieNode {
  String value;
  List<TrieNode> children;
  late int lastInsert;
  int hits = 0;

  TrieNode(this.value, bool isEnd) : children = <TrieNode>[];

  @override
  bool operator ==(covariant TrieNode other) {
    return value == other.value;
  }

  @override
  int get hashCode => value.hashCode;
}
