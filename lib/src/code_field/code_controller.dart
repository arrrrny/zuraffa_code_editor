// ignore_for_file: parameter_assignments

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight_core.dart';
import 'package:meta/meta.dart';

import '../../zuraffa_code_editor.dart';
import '../autocomplete/autocompleter.dart';
import '../code/code_edit_result.dart';
import '../code/key_event.dart';
import '../code_modifiers/insertion.dart';
import '../highlight/mode_patches.dart';
import '../highlight/sub_languages.dart';
import '../history/code_history_controller.dart';
import '../history/code_history_record.dart';
import '../search/controller.dart';
import '../search/result.dart';
import '../search/search_navigation_controller.dart';
import '../search/settings_controller.dart';
import '../single_line_comments/parser/single_line_comments.dart';
import '../util/string_util.dart';
import '../wip/autocomplete/popup_controller.dart';
import 'actions/comment_uncomment.dart';
import 'actions/copy.dart';
import 'actions/dismiss.dart';
import 'actions/enter_key.dart';
import 'actions/indent.dart';
import 'actions/outdent.dart';
import 'actions/overtype.dart';
import 'actions/redo.dart';
import 'actions/search.dart';
import 'actions/tab.dart';
import 'actions/undo.dart';
import 'search_result_highlighted_builder.dart';
import 'span_builder.dart';

/// Everything [CodeController.buildTextSpan] reads, in one value.
///
/// A record rather than a class so the comparison is the language's own
/// structural `==`, which is exactly the semantics this key needs:
/// [TextStyle], [SearchResult] and the navigation index implement value
/// equality, and the three components that do not — [Code], [CodeThemeData]
/// and [Mode] — compare by identity. Picking that per component by hand is how
/// a cache key gets one of them wrong, and a key that is wrong is not a slower
/// version of this feature: `RenderParagraph` trusts an identical span
/// unconditionally (`rendering/paragraph.dart`,
/// `case RenderComparison.identical: return;`), so a hit on an unchanged key
/// paints a stale tree.
///
/// A component missing from here is a stale render; a component here that never
/// changes is only a missed cache hit. So the list is every input the build
/// reads, and the tests assert each one is load-bearing.
typedef _SpanCacheKey = ({
  Code code,
  TextStyle? style,
  CodeThemeData? theme,
  Mode? language,
  SearchResult searchResult,
  int? currentMatchIndex,
});

class CodeController extends TextEditingController {
  Mode? _language;

  /// A highlight language to parse the text with
  ///
  /// Setting a language will change the analyzer to [DefaultLocalAnalyzer].
  ///
  /// Any [Mode] works, including one this package does not ship: the controller
  /// registers the mode it is handed under a key of its own and parses with that
  /// key, so an unlisted language highlights without any extra call. Do
  /// **not** call `highlight.registerLanguage` yourself — the name you pick is
  /// not the key the controller parses with, so that registration is either
  /// unused or, if you happened to collide with the controller's synthetic key,
  /// actively harmful. Hand your mode straight to `language` and it is used.
  Mode? get language => _language;

  set language(Mode? language) {
    setLanguage(language, analyzer: const DefaultLocalAnalyzer());
  }

  /// `CodeController` uses [analyzer] to generate issues
  /// that are displayed in gutter widget.
  ///
  /// Calls [AbstractAnalyzer.analyze] after change with 500ms debounce.
  AbstractAnalyzer get analyzer => _analyzer;
  AbstractAnalyzer _analyzer;

  set analyzer(AbstractAnalyzer analyzer) {
    if (_analyzer == analyzer) {
      return;
    }

    _analyzer = analyzer;
    unawaited(analyzeCode());
  }

  AnalysisResult analysisResult;
  String _lastAnalyzedText = '';
  Timer? _debounce;

  final AbstractNamedSectionParser? namedSectionParser;
  Set<String> _readOnlySectionNames;

  /// A map of specific regexes to style
  final Map<String, TextStyle>? patternMap;

  /// Common editor params such as the size of a tab in spaces
  ///
  /// Will be exposed to all [modifiers]
  final EditorParams params;

  /// A list of code modifiers
  /// to dynamically update the code upon certain keystrokes.
  final List<CodeModifier> modifiers;

  final bool _isTabReplacementEnabled;

  /* Computed members */
  String _languageId = '';

  ///Contains names of named sections, those will be visible for user.
  ///If it is not empty, all another code except specified will be hidden.
  Set<String> _visibleSectionNames = {};

  /// Makes the text un-editable, but allows to set the full text.
  /// Focusing and moving the selection inside of a [CodeField] will
  /// still be possible.
  final bool readOnly;

  String get languageId => _languageId;

  Code _code;

  /// The selection a fold truncated, kept in full-text coordinates.
  ///
  /// Set by [_getValueWithCode] and cleared by anything that re-establishes
  /// the selection in the visible text: a change from the field, or an edit
  /// of its own. See [_getValueWithCode].
  TextSelection? _selectionHiddenByFold;

  final _styleList = <TextStyle>[];
  final _modifierMap = <String, CodeModifier>{};

  /// Modifiers that react to a character being removed, keyed by that character
  /// — the deletion counterpart of [_modifierMap]. See
  /// [CodeModifier.deletesChar].
  final _deletionModifierMap = <String, CodeModifier>{};

  /// Commands the suggestion popup.
  ///
  /// The popup is a *view of state this controller owns* — which completions
  /// exist, whether they are showing, which one is selected — so every move it
  /// makes is driven from here rather than from the widget that paints it.
  /// The call sites, and why each exists:
  ///
  /// - [_onKeyDownRepeat] — arrow keys move the selection;
  /// - [onEnterKeyAction] and [onTabKeyAction] — enter/tab commit the selected
  ///   completion, which reads as inserting a word here;
  /// - [insertSelectedWord] — hides the popup once the word is in;
  /// - `set value` — a selection change or the end of an IME composition
  ///   dismisses suggestions, because the text they were computed from moved;
  /// - [generateSuggestions] — shows or hides after recomputing;
  /// - [_dismissSuggestions] — honours the popup's own `enabled` gate.
  ///
  /// The popup is wired to the field by `CodeField`, which listens for changes
  /// here to insert or remove its overlay. A host does not need to touch this
  /// to theme the popup: `CodeField.suggestionItemBuilder` builds its rows and
  /// `CodeField.autocompleteBackground` sets its background, both without
  /// reaching into this controller.
  late PopupController popupController;
  final autocompleter = Autocompleter();
  late final historyController = CodeHistoryController(codeController: this);

  @internal
  late final searchController = CodeSearchController(codeController: this);

  SearchSettingsController get _searchSettingsController =>
      searchController.settingsController;

  SearchNavigationController get _searchNavigationController =>
      searchController.navigationController;

  @internal
  SearchResult fullSearchResult = SearchResult.empty;

  /// The last [TextSpan] returned from [buildTextSpan].
  ///
  /// This can be used in tests to make sure that the updated text  was actually
  /// requested by the widget and thus notifications are done right.
  ///
  /// Note that with the span cache in [buildTextSpan], a non-changing call does
  /// not request the text at all — it returns the cached span. So this field
  /// says which span was last *served*, not which was last *built*.
  @visibleForTesting
  TextSpan? lastTextSpan;

  /// What [_cachedTextSpan] was built from, and the span itself.
  ///
  /// One entry, replaced on the first call whose inputs differ. See
  /// [_SpanCacheKey].
  _SpanCacheKey? _spanCacheKey;
  TextSpan? _cachedTextSpan;

  /// Tints the background of individual lines.
  ///
  /// Called once per rendered line with the line's index in the full, unfolded
  /// buffer — 0-based, the same coordinate space as [Issue.line] and
  /// [FoldableBlock.firstLine]. Return the colour to tint that line's row with,
  /// or null to leave it untinted.
  ///
  /// The tint covers the full width of the line's row, including the stretch
  /// past the last character, and it sits behind the editor's search-match
  /// highlighting, which still wins on a matched run. Lines inside a folded
  /// block or a hidden section are not rendered, so the builder is not called
  /// for them.
  ///
  /// Left null, the editor renders exactly as it does without this field: the
  /// background layer is not built at all. Reassign it and notify listeners to
  /// re-render.
  ///
  /// A line index is not a character offset, so following the cursor means
  /// converting the caret's offset first. [currentLineColor] does that
  /// conversion and is the easier way to write this:
  ///
  /// ```dart
  /// controller.currentLineColor = Colors.yellow.withValues(alpha: 0.1);
  /// ```
  Color? Function(int lineIndex)? lineBackgroundBuilder;

  /// Tints the background of the line the caret is on, across the full width of
  /// that line's row — VSCode's `editor.renderLineHighlight: all`.
  ///
  /// The tint follows the caret as it moves, by whatever moves it: typing,
  /// tapping, arrow keys, or assigning a new selection to this controller.
  /// "The line the caret is on" is the line of [TextSelection.extentOffset] —
  /// the end that moves, so a shift-arrow from line 2 down to line 10
  /// highlights line 10, the caret, and not line 2, the anchor. With a
  /// collapsed caret — the common case — the two are the same line. A selection
  /// spanning several lines is tinted on the caret's line only, never across
  /// the whole selection.
  ///
  /// The offset-to-line conversion is the editor's job, not a host's: it uses
  /// `Code.lines.characterIndexToLineIndex`, which maps a character offset onto
  /// the line's index in the full, unfolded buffer. A caret at the very end of
  /// the text counts as being on the last line. A caret with no selection at
  /// all — the `-1` offset an untouched [TextEditingValue] carries — and a
  /// caret whose offset is past the text while the code catches up with an
  /// edit both tint nothing.
  ///
  /// Composes with [lineBackgroundBuilder], and the builder wins: for each line
  /// the builder's answer is used when it returns one, and this colour fills in
  /// only the lines the builder leaves null. A host that already tints specific
  /// lines therefore keeps that behaviour and gains a cursor follower underneath
  /// it.
  ///
  /// Left null — and with [lineBackgroundBuilder] also null — the editor
  /// renders exactly as it does without either field: the background layer is
  /// not built at all.
  Color? currentLineColor;

  bool _disposed = false;

  /// Whether typing replaces the character after the caret (overtype) instead
  /// of inserting in front of it.
  ///
  /// Starts false: the editor inserts. The Insert key toggles it while the
  /// field is focused, and the host can read or set it directly.
  ///
  /// Only a plain one-character keystroke at a collapsed caret replaces: an
  /// edit a code modifier transforms (auto-pairing, smart indent), a deletion,
  /// a paste, or a caret at the end of the text all behave as they do in
  /// insert mode.
  bool isOvertypeMode = false;

  /// Flips [isOvertypeMode]. Wired to the Insert key by
  /// `ToggleOvertypeAction`.
  void toggleOvertypeMode() {
    isOvertypeMode = !isOvertypeMode;
  }

  late final actions = <Type, Action<Intent>>{
    CommentUncommentIntent: CommentUncommentAction(controller: this),
    CopySelectionTextIntent: CopyAction(controller: this),
    IndentIntent: IndentIntentAction(controller: this),
    OutdentIntent: OutdentIntentAction(controller: this),
    RedoTextIntent: RedoAction(controller: this),
    UndoTextIntent: UndoAction(controller: this),
    SearchIntent: SearchAction(controller: this),
    DismissIntent: CustomDismissAction(controller: this),
    EnterKeyIntent: EnterKeyAction(controller: this),
    TabKeyIntent: TabKeyAction(controller: this),
    ToggleOvertypeIntent: ToggleOvertypeAction(controller: this),
  };

  static const defaultCodeModifiers = [
    IndentModifier(),
    CloseBlockModifier(),
    TabModifier(),
    OutdentModifier(),
    InsertionCodeModifier.backticks,
    InsertionCodeModifier.braces,
    InsertionCodeModifier.brackets,
    InsertionCodeModifier.doubleQuotes,
    InsertionCodeModifier.parentheses,
    InsertionCodeModifier.singleQuotes,
  ];

  CodeController({
    String? text,
    Mode? language,
    AbstractAnalyzer analyzer = const DefaultLocalAnalyzer(),
    this.namedSectionParser,
    Set<String> readOnlySectionNames = const {},
    Set<String> visibleSectionNames = const {},
    this.analysisResult = const AnalysisResult(issues: []),
    this.patternMap,
    this.readOnly = false,
    this.params = const EditorParams(),
    this.modifiers = defaultCodeModifiers,
  }) : _analyzer = analyzer,
       _readOnlySectionNames = readOnlySectionNames,
       _code = Code.empty,
       _isTabReplacementEnabled = modifiers.any((e) => e is TabModifier) {
    setLanguage(language, analyzer: analyzer);
    this.visibleSectionNames = visibleSectionNames;
    _code = _createCode(text ?? '');
    fullText = text ?? '';

    addListener(_scheduleAnalysis);
    addListener(_updateSearchResult);
    _searchSettingsController.addListener(_updateSearchResult);
    // This listener is called when search controller notifies about
    // showing or hiding the search popup.
    searchController.addListener(_updateSearchResult);

    // Create modifier map
    for (final el in modifiers) {
      final deletesChar = el.deletesChar;

      if (deletesChar != null) {
        _deletionModifierMap[deletesChar] = el;
      } else {
        _modifierMap[el.char] = el;
      }
    }

    // Build styleRegExp
    final patternList = <String>[];
    if (patternMap != null) {
      patternList.addAll(patternMap!.keys.map((e) => '($e)'));
      _styleList.addAll(patternMap!.values);
    }

    popupController = PopupController(onCompletionSelected: insertSelectedWord);

    unawaited(analyzeCode());
  }

  void _updateSearchResult() {
    final result = searchController.search(
      code,
      settings: _searchSettingsController.value,
    );

    if (result == fullSearchResult) {
      return;
    }

    fullSearchResult = result;
    notifyListeners();
  }

  void _scheduleAnalysis() {
    _debounce?.cancel();

    if (_lastAnalyzedText == _code.text) {
      // If the last analyzed code is the same as current code
      // we don't need to analyze it again.
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await analyzeCode();
    });
  }

  Future<void> analyzeCode() async {
    final codeSentToAnalysis = _code;
    final result = await _analyzer.analyze(codeSentToAnalysis);

    if (_code.text != codeSentToAnalysis.text) {
      // If the code has been changed before we got analysis result, discard it.
      // This happens on request race condition.
      return;
    }

    if (_disposed) {
      return;
    }

    analysisResult = result;
    _lastAnalyzedText = codeSentToAnalysis.text;
    notifyListeners();
  }

  void setLanguage(Mode? language, {required AbstractAnalyzer analyzer}) {
    if (language == _language) {
      return;
    }

    if (language != null) {
      _languageId = language.hashCode.toString();
      highlight.registerLanguage(_languageId, modeToRegister(language));
      _registerSubLanguages(language);
    }

    _language = language;
    autocompleter.mode = language;
    _updateCode(_code.text);
    this.analyzer = analyzer;
    notifyListeners();
  }

  /// Registers every language [language] can embed under the name it names it.
  ///
  /// `highlight` looks an embedded sub-language up **by name** in the language
  /// registry, so a mode that embeds one cannot find it unless that name is
  /// registered. Without this, `_processSubLanguage` gives up and hands the
  /// embedded fragment back as one plain node — markdown's `<b>html</b>`, dart's
  /// doc comments, erb's Ruby, and every other embedding silently lose their
  /// highlighting.
  ///
  /// The references live on child modes, not on the top one (markdown's
  /// `Mode(begin: "<", end: ">", subLanguage: ["xml"])` is one of its
  /// `contains`), so the tree is walked. The walk then follows the referenced
  /// languages' own references — dart embeds markdown, whose mode embeds xml —
  /// so a second-level embed is registered too; each name is handled once,
  /// which bounds the walk over [subLanguages] even though some modes
  /// reference each other in a cycle (xml and xquery include themselves).
  /// Only the names this mode's graph reaches are registered, so setting a
  /// language cannot make another language's embeddings worse, and a reference
  /// outside [subLanguages] stays exactly as unhighlighted as it was before.
  void _registerSubLanguages(Mode language) {
    final references = <String>{};
    _collectSubLanguageReferences(language, references, {});
    if (references.isEmpty) {
      return;
    }

    final pending = references.toList();
    final handled = <String>{};
    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      if (!handled.add(name)) {
        continue;
      }

      final subLanguage = subLanguages[name];
      if (subLanguage == null) {
        continue;
      }

      highlight.registerLanguage(name, subLanguage);
      final nested = <String>{};
      _collectSubLanguageReferences(subLanguage, nested, {});
      pending.addAll(nested);
    }
  }

  /// Gathers every sub-language name reachable from [mode], following
  /// `contains`, `variants`, `starts` and `refs` the way the highlighter's
  /// own compiler does, and skipping modes already [seen] so a self- or
  /// cross-referencing mode cannot loop.
  void _collectSubLanguageReferences(
    Mode mode,
    Set<String> into,
    Set<Mode> seen,
  ) {
    if (!seen.add(mode)) {
      return;
    }

    into.addAll(mode.subLanguage ?? const []);

    for (final child in mode.contains ?? const <Mode?>[]) {
      if (child != null) {
        _collectSubLanguageReferences(child, into, seen);
      }
    }
    for (final variant in mode.variants ?? const <Mode?>[]) {
      if (variant != null) {
        _collectSubLanguageReferences(variant, into, seen);
      }
    }
    final starts = mode.starts;
    if (starts != null) {
      _collectSubLanguageReferences(starts, into, seen);
    }
    for (final ref in mode.refs?.values ?? const <Mode>[]) {
      _collectSubLanguageReferences(ref, into, seen);
    }
  }

  /// Sets a specific cursor position in the text
  void setCursor(int offset) {
    selection = TextSelection.collapsed(offset: offset);
  }

  /// Replaces the current [selection] by [str]
  void insertStr(String str) {
    final sel = selection;
    text = text.replaceRange(selection.start, selection.end, str);
    final len = str.length;

    selection = sel.copyWith(
      baseOffset: sel.start + len,
      extentOffset: sel.start + len,
    );
  }

  /// Remove the char just before the cursor or the selection
  void removeChar() {
    if (selection.start < 1) {
      return;
    }

    final sel = selection;
    text = text.replaceRange(selection.start - 1, selection.start, '');

    selection = sel.copyWith(
      baseOffset: sel.start - 1,
      extentOffset: sel.start - 1,
    );
  }

  /// Remove the selected text
  void removeSelection() {
    final sel = selection;
    text = text.replaceRange(selection.start, selection.end, '');

    selection = sel.copyWith(baseOffset: sel.start, extentOffset: sel.start);
  }

  /// Remove the selection or last char if the selection is empty
  void backspace() {
    if (selection.start < selection.end) {
      removeSelection();
    } else {
      removeChar();
    }
  }

  KeyEventResult onKey(KeyEvent event) {
    if (hasActiveComposition) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      return _onKeyDownRepeat(event);
    }

    return KeyEventResult.ignored; // The framework will handle.
  }

  /// Whether the platform reports an in-progress IME composition,
  /// e.g. Chinese pinyin or Japanese kana input.
  ///
  /// While composing, the code text and the selection are owned by the
  /// platform: applying diff-based transforms or shortcuts on top of it
  /// corrupts the composition commit.
  static bool _hasActiveComposing(TextRange composing) {
    return composing.isValid && !composing.isCollapsed;
  }

  bool get hasActiveComposition {
    return _hasActiveComposing(value.composing);
  }

  KeyEventResult _onKeyDownRepeat(KeyEvent event) {
    if (event.isCtrlF(HardwareKeyboard.instance.logicalKeysPressed)) {
      showSearch();
      return KeyEventResult.handled;
    }

    if (popupController.shouldShow) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        popupController.scrollByArrow(ScrollDirection.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        popupController.scrollByArrow(ScrollDirection.down);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored; // The framework will handle.
  }

  void onEnterKeyAction() {
    if (hasActiveComposition) {
      return;
    }

    if (popupController.shouldShow) {
      insertSelectedWord();
      return;
    }

    final currentMatchIndex =
        _searchNavigationController.value.currentMatchIndex;

    if (searchController.shouldShow && currentMatchIndex != null) {
      final fullSelection = code.hiddenRanges.recoverSelection(selection);
      final currentMatch = fullSearchResult.matches[currentMatchIndex];

      if (fullSelection.start == currentMatch.start &&
          fullSelection.end == currentMatch.end) {
        _searchNavigationController.moveNext();
        return;
      }
    }

    insertStr('\n');
  }

  void onTabKeyAction() {
    if (hasActiveComposition) {
      return;
    }

    if (popupController.shouldShow) {
      insertSelectedWord();
      return;
    }

    insertStr(' ' * params.tabSpaces);
  }

  /// Inserts the word selected from the list of completions
  void insertSelectedWord() {
    final previousSelection = selection;
    final selectedWord = popupController.getSelectedWord();
    final startPosition = value.wordAtCursorStart;
    final currentWord = value.wordAtCursor;

    if (startPosition == null || currentWord == null) {
      popupController.hide();
      return;
    }

    final endReplacingPosition = startPosition + currentWord.length;
    final endSelectionPosition = startPosition + selectedWord.length;

    var additionalSpaceIfEnd = '';
    var offsetIfEndsWithSpace = 1;
    if (text.length < endReplacingPosition + 1) {
      additionalSpaceIfEnd = ' ';
    } else {
      final charAfterText = text[endReplacingPosition];
      if (charAfterText != ' ' &&
          !StringUtil.isDigit(charAfterText) &&
          !StringUtil.isLetterEng(charAfterText)) {
        // ex. case ';' or other finalizer, or symbol
        offsetIfEndsWithSpace = 0;
      }
    }

    final replacedText = text.replaceRange(
      startPosition,
      endReplacingPosition,
      '$selectedWord$additionalSpaceIfEnd',
    );

    final adjustedSelection = previousSelection.copyWith(
      baseOffset: endSelectionPosition + offsetIfEndsWithSpace,
      extentOffset: endSelectionPosition + offsetIfEndsWithSpace,
    );

    value = TextEditingValue(text: replacedText, selection: adjustedSelection);

    popupController.hide();
  }

  String get fullText => _code.text;

  set fullText(String fullText) {
    _updateCodeIfChanged(_replaceTabsWithSpacesIfNeeded(fullText));
    // The new text carries a selection of its own, so any selection a fold
    // truncated from the previous document is superseded by it.
    _selectionHiddenByFold = null;
    super.value = TextEditingValue(text: _code.visibleText);
  }

  int? _insertedLoc(String a, String b) {
    final sel = selection;

    if (a.length + 1 != b.length || sel.start != sel.end || sel.start == -1) {
      return null;
    }

    return sel.start;
  }

  /// [newValue] as the platform would deliver it, rewritten so that a plain
  /// one-character keystroke replaces the character after the caret instead of
  /// inserting in front of it, or null when [newValue] is not such a keystroke.
  ///
  /// The rewrite is scoped to a keystroke the platform applied at the caret:
  /// [_insertedLoc] states that the text grew by exactly one at a collapsed
  /// caret, and [newValue]'s own selection has to have landed one past that
  /// insertion. Anything else — a deletion, a paste, a selection, a line
  /// break, an edit a code modifier transformed, or a caret at the end of the
  /// text — falls through to the ordinary insert.
  TextEditingValue? _overtypedValue(TextEditingValue newValue) {
    final loc = _insertedLoc(text, newValue.text);
    if (loc == null || loc >= text.length || newValue.text[loc] == '\n') {
      return null;
    }

    final newSelection = newValue.selection;
    if (!newSelection.isCollapsed || newSelection.start != loc + 1) {
      return null;
    }

    // A character outside the BMP spans two code units: replacing only the
    // lead surrogate would strand the trailing half in the document, so the
    // whole pair is consumed either way.
    final unit = text.codeUnitAt(loc);
    final end = unit >= 0xD800 && unit <= 0xDBFF && loc + 1 < text.length
        ? loc + 2
        : loc + 1;

    return TextEditingValue(
      text: text.replaceRange(loc, end, newValue.text[loc]),
      selection: TextSelection.collapsed(offset: loc + 1),
    );
  }

  /// The offset of the character a single-character deletion removed from [a],
  /// or null when [b] was not produced by exactly that.
  ///
  /// The mirror of [_insertedLoc]: there the text grew by one and the caret sat
  /// after the inserted character; here it shrank by one and the caret sits
  /// where the removed character had been. [newSel] is the selection of the
  /// value being assigned, because the field's own [selection] still reports the
  /// pre-deletion caret at this point.
  int? _deletedLoc(String a, String b, TextSelection newSel) {
    if (a.length != b.length + 1 || !newSel.isCollapsed) {
      return null;
    }

    final deleted = newSel.start;
    if (deleted < 0 || deleted >= a.length) {
      return null;
    }

    if (a.substring(0, deleted) + a.substring(deleted + 1) != b) {
      return null;
    }

    return deleted;
  }

  @override
  set value(TextEditingValue newValue) {
    final hadActiveCompositionInOldValue = hasActiveComposition;
    final hasTextChanged = newValue.text != super.value.text;
    final hasSelectionChanged = newValue.selection != super.value.selection;
    final hasComposingChanged = newValue.composing != super.value.composing;
    final hasActiveComposingInNewValue = _hasActiveComposing(
      newValue.composing,
    );

    if (!hasTextChanged && !hasSelectionChanged && !hasComposingChanged) {
      return;
    }

    // A change from the field re-establishes the selection in the visible
    // text, so whatever a fold had truncated is no longer what the user is
    // pointing at.
    _selectionHiddenByFold = null;

    if (hasActiveComposingInNewValue || hadActiveCompositionInOldValue) {
      if (readOnly && hasTextChanged) {
        return;
      }

      // A tab is not an editor transform: it is a character no font the editor
      // can rely on draws (flutter/flutter#79153), so it is converted here too,
      // where the rest of the value setter converts it. This must precede the
      // hidden-ranges early return below, which would otherwise pass a raw tab
      // straight through whenever a block is folded.
      if (_isTabReplacementEnabled && hasTextChanged) {
        newValue = newValue.tabsToSpaces(params.tabSpaces);
      }

      // Rebuilding the full text from the visible text would silently drop
      // folded content; the diff path maps the edit into the full text.
      if (hasTextChanged && code.hiddenRanges.ranges.isNotEmpty) {
        historyController.beforeCodeControllerValueChanged(
          code: _code,
          selection: newValue.selection,
          isTextChanging: true,
        );
        super.value = newValue;
        return;
      }

      // During IME composition, preserve platform-provided editing state
      // and avoid applying editor transforms that may break composition commit.
      // Keep internal code state in sync so highlighted rendering doesn't drift.
      if (hasTextChanged) {
        _updateCodeIfChanged(newValue.text);
      }

      // The update that ends a composition is a commit: the popup's
      // suggestions were computed from the pre-composition text and must
      // not survive it.
      if (hadActiveCompositionInOldValue && !hasActiveComposingInNewValue) {
        popupController.hide();
      }

      super.value = newValue;
      return;
    }

    if (hasTextChanged) {
      final loc = _insertedLoc(text, newValue.text);

      if (loc != null) {
        final char = newValue.text[loc];
        final modifier = _modifierMap[char];
        final val = modifier?.updateString(text, selection, params);

        if (val != null) {
          // Update newValue
          newValue = newValue.copyWith(
            text: val.text,
            selection: val.selection,
          );
        }
      } else {
        // A deletion removes a character instead of inserting one, so there is
        // no typed character to key the dispatch on. The character that was
        // removed stands in for it — see CodeModifier.deletesChar.
        final newSel = newValue.selection;
        final candidate = newSel.isCollapsed ? newSel.start : -1;
        final modifier = candidate >= 0 && candidate < text.length
            ? _deletionModifierMap[text[candidate]]
            : null;

        // The probe above uses the unverified index; _deletedLoc still
        // confirms the deletion before updateString runs.
        if (modifier != null &&
            _deletedLoc(text, newValue.text, newSel) != null) {
          final val = modifier.updateString(text, selection, params);

          if (val != null) {
            newValue = newValue.copyWith(
              text: val.text,
              selection: val.selection,
            );
          }
        }
      }

      if (_isTabReplacementEnabled) {
        newValue = newValue.tabsToSpaces(params.tabSpaces);
      }

      if (isOvertypeMode && !readOnly) {
        newValue = _overtypedValue(newValue) ?? newValue;
      }

      final editResult = _getEditResultNotBreakingReadOnly(newValue);

      if (editResult == null) {
        return;
      }

      final selectionSnapshot = code.hiddenRanges.recoverSelection(
        newValue.selection,
      );
      _updateCodeIfChanged(
        editResult.fullTextAfter,
        changedOldLines: editResult.linesChanged,
      );

      if (newValue.text != _code.visibleText) {
        if (!newValue.selection.isCollapsed &&
            newValue.text.length > _code.visibleText.length) {
          // Manually typed in a text that has become a hidden range.
          newValue = newValue.replacedText(_code.visibleText);
        } else {
          // A paste, or a folded block is unfolded: the framework's caret
          // offset is meaningful in the full text — keep it.
          newValue = TextEditingValue(
            text: _code.visibleText,
            selection: _code.hiddenRanges.cutSelection(selectionSnapshot),
          );
        }
      }

      // Uncomment this to see the hidden text in the console
      // as you change the visible text.
      //print('\n\n${_code.text}');
    }

    historyController.beforeCodeControllerValueChanged(
      code: _code,
      selection: newValue.selection,
      isTextChanging: hasTextChanged,
    );

    super.value = newValue;

    if (hasTextChanged) {
      autocompleter.blacklist = [newValue.wordAtCursor ?? ''];
      autocompleter.setText(this, text);
      unawaited(generateSuggestions());
    } else if (hasSelectionChanged) {
      popupController.hide();
    }
  }

  void applyHistoryRecord(CodeHistoryRecord record) {
    _code = record.code.foldedAs(_code);
    final fullSelection = record.code.hiddenRanges.recoverSelection(
      record.selection,
    );
    final cutSelection = _code.hiddenRanges.cutSelection(fullSelection);

    // The record carries its own selection, so any selection a fold truncated
    // is superseded by it.
    _selectionHiddenByFold = null;

    super.value = TextEditingValue(
      text: code.visibleText,
      selection: cutSelection,
    );
  }

  void outdentSelection() {
    final tabSpaces = params.tabSpaces;
    if (selection.start == -1 || selection.end == -1) {
      return;
    }

    modifySelectedLines((line) {
      if (line == '\n') {
        return line;
      }

      if (line.length < tabSpaces) {
        return line.trimLeft();
      }

      final subStr = line.substring(0, tabSpaces);
      if (subStr == ' ' * tabSpaces) {
        return line.substring(tabSpaces, line.length);
      }
      return line.trimLeft();
    });
  }

  void indentSelection() {
    final tabSpaces = params.tabSpaces;
    final tab = ' ' * tabSpaces;
    final lines = _code.lines.lines;
    if (selection.start == -1 || selection.end == -1) {
      return;
    }

    if (selection.isCollapsed) {
      final fullPosition = _code.hiddenRanges.recoverPosition(
        selection.start,
        placeHiddenRanges: TextAffinity.downstream,
      );
      final lineIndex = _code.lines.characterIndexToLineIndex(fullPosition);
      final columnIndex = fullPosition - lines[lineIndex].textRange.start;
      final insert = ' ' * (tabSpaces - (columnIndex % tabSpaces));
      value = value.replaced(selection, insert);
      return;
    }

    modifySelectedLines((line) {
      if (line == '\n') {
        return line;
      }
      return tab + line;
    });
  }

  /// Comments out or uncomments the currently selected lines.
  ///
  /// Doesn't affect empty lines.
  ///
  /// If any of the selected lines is not a single line comment:
  /// adds one level of single line comment to every selected line.
  ///
  /// If all of the selected lines are single line comments:
  /// removes one level of single line comment from every selected line.
  ///
  /// When commenting out, adds `// ` or `# ` (or another symbol depending on a language) with a space after.
  /// Removes these spaces on uncommenting.
  /// (if there are no spaces just removes the comments)
  ///
  /// The method doesn't account for multiline comments
  /// and treats them as a normal text (not a comment).
  void commentOutOrUncommentSelection() {
    if (_anySelectedLineUncommented()) {
      _commentOutSelectedLines();
    } else {
      _uncommentSelectedLines();
    }
  }

  bool _anySelectedLineUncommented() {
    return _anySelectedLine((line) {
      for (final commentType in SingleLineComments.byMode[language] ?? []) {
        if (line.trimLeft().startsWith(commentType) ||
            line.hasOnlyWhitespaces()) {
          return false;
        }
      }
      return true;
    });
  }

  /// Whether any of the selected lines meets the condition in the callback.
  bool _anySelectedLine(bool Function(String line) callback) {
    if (selection.start == -1 || selection.end == -1) {
      return false;
    }

    final selectedLinesRange = getSelectedLineRange();

    for (int i = selectedLinesRange.start; i < selectedLinesRange.end; i++) {
      final currentLineMatchesCondition = callback(_code.lines.lines[i].text);
      if (currentLineMatchesCondition) {
        return true;
      }
    }

    return false;
  }

  void _commentOutSelectedLines() {
    final sequence = SingleLineComments.byMode[language]?.first;
    if (sequence == null) {
      return;
    }

    modifySelectedLines((line) {
      if (line.hasOnlyWhitespaces()) {
        return line;
      }

      return line.replaceRange(0, 0, '$sequence ');
    });
  }

  void _uncommentSelectedLines() {
    modifySelectedLines((line) {
      if (line.hasOnlyWhitespaces()) {
        return line;
      }

      for (final sequence
          in SingleLineComments.byMode[language] ?? <String>[]) {
        // If there is a space after a sequence
        // we should remove it with the sequence.
        if (line.trim().startsWith('$sequence ')) {
          return line.replaceFirst('$sequence ', '');
        }
        // If there is no space after a sequence
        // we should remove the sequence.
        if (line.trim().startsWith(sequence)) {
          return line.replaceFirst(sequence, '');
        }
      }

      // If line is not commented just return it.
      return line;
    });
  }

  /// Filters the lines that have at least one character selected.
  ///
  /// IMPORTANT: this method also changes the selection to be:
  /// start: start of the first selected line
  /// end: end of the last line
  ///
  /// Folded blocks are considered to be selected
  /// if they are located between start and end of a selection.
  ///
  /// [modifierCallback] - transformation function that modifies the line.
  /// `line` in the callback contains '\n' symbol at the end, except for the last line of the document.
  // TODO(yescorp): need to preserve folding..
  void modifySelectedLines(String Function(String line) modifierCallback) {
    if (readOnly) {
      return;
    }

    if (selection.start == -1 || selection.end == -1) {
      return;
    }

    final lineRange = getSelectedLineRange();

    // Apply modification to the selected lines.
    final modifiedLinesBuffer = StringBuffer();
    for (int i = lineRange.start; i < lineRange.end; i++) {
      // Cancel modification entirely if any of the lines is readOnly.
      if (_code.lines.lines[i].isReadOnly) {
        return;
      }
      final modifiedString = modifierCallback(_code.lines.lines[i].text);
      modifiedLinesBuffer.write(modifiedString);
    }

    final modifiedLinesString = modifiedLinesBuffer.toString();

    final firstLineStart = _code.lines.lines[lineRange.start].textRange.start;
    final lastLineEnd = _code.lines.lines[lineRange.end - 1].textRange.end;

    // Replace selected lines with modified ones.
    final finalFullText = _code.text.replaceRange(
      firstLineStart,
      lastLineEnd,
      modifiedLinesString,
    );

    _updateCodeIfChanged(finalFullText);

    final finalFullSelection = TextSelection(
      baseOffset: firstLineStart,
      extentOffset: firstLineStart + modifiedLinesString.length,
    );
    final finalVisibleSelection = _code.hiddenRanges.cutSelection(
      finalFullSelection,
    );

    // TODO(yescorp): move to the listener both here and in `set value`
    //  or come up with a different approach
    historyController.beforeCodeControllerValueChanged(
      code: _code,
      selection: finalVisibleSelection,
      isTextChanging: true,
    );

    // The edit selects the modified lines, so any selection a fold truncated
    // is superseded by that new selection.
    _selectionHiddenByFold = null;

    super.value = TextEditingValue(
      text: _code.visibleText,
      selection: finalVisibleSelection,
    );
  }

  TextRange getSelectedLineRange() {
    final firstChar = _code.hiddenRanges.recoverPosition(
      selection.start,
      placeHiddenRanges: TextAffinity.downstream,
    );
    final lastChar = _code.hiddenRanges.recoverPosition(
      // To avoid including the next line if `\n` is selected.
      selection.isCollapsed ? selection.end : selection.end - 1,
      placeHiddenRanges: TextAffinity.downstream,
    );

    final firstLineIndex = _code.lines.characterIndexToLineIndex(firstChar);
    final lastLineIndex = _code.lines.characterIndexToLineIndex(lastChar);

    return TextRange(start: firstLineIndex, end: lastLineIndex + 1);
  }

  Code get code => _code;

  CodeEditResult? _getEditResultNotBreakingReadOnly(TextEditingValue newValue) {
    if (readOnly) {
      return null;
    }

    final editResult = _code.getEditResult(value.selection, newValue);
    if (!_code.isReadOnlyInLineRange(editResult.linesChanged)) {
      return editResult;
    }

    return null;
  }

  void _updateCodeIfChanged(String text, {TextRange? changedOldLines}) {
    if (text != _code.text) {
      _updateCode(text, changedOldLines: changedOldLines);
    }
  }

  void _updateCode(String text, {TextRange? changedOldLines}) {
    final newCode = _createCode(text);
    _code = newCode.foldedAs(_code, changedOldLines: changedOldLines);
  }

  Code _createCode(String text) {
    return Code(
      text: text,
      language: language,
      highlighted: highlight.parse(text, language: _languageId),
      namedSectionParser: namedSectionParser,
      readOnlySectionNames: _readOnlySectionNames,
      visibleSectionNames: _visibleSectionNames,
    );
  }

  String _replaceTabsWithSpacesIfNeeded(String text) {
    if (modifiers.contains(const TabModifier())) {
      return text.replaceAll('\t', ' ' * params.tabSpaces);
    }
    return text;
  }

  Future<void> generateSuggestions() async {
    final prefix = value.wordToCursor;
    if (prefix == null) {
      popupController.hide();
      return;
    }

    final suggestions = (await autocompleter.getSuggestions(
      prefix,
    )).toList(growable: false);

    if (suggestions.isNotEmpty) {
      popupController.show(suggestions);
    } else {
      popupController.hide();
    }
  }

  void foldAt(int line) {
    final newCode = _code.foldedAt(line);
    super.value = _getValueWithCode(newCode);

    _code = newCode;
  }

  void unfoldAt(int line) {
    final newCode = _code.unfoldedAt(line);
    super.value = _getValueWithCode(newCode);

    _code = newCode;
  }

  /// Folds [blocks] in one pass: one new [Code], one value assignment and
  /// one listener notification, regardless of how many blocks are folded.
  ///
  /// A block that is already folded, or that the current code no longer
  /// holds, is skipped. When nothing remains to fold, no value is assigned.
  void foldBlocks(Iterable<FoldableBlock> blocks) {
    var newCode = _code;

    for (final block in blocks) {
      newCode = newCode.foldedBlock(block);
    }

    if (identical(newCode, _code)) {
      return;
    }

    super.value = _getValueWithCode(newCode);

    _code = newCode;
  }

  Set<String> get readOnlySectionNames => _readOnlySectionNames;

  set readOnlySectionNames(Set<String> newValue) {
    _readOnlySectionNames = newValue;
    _updateCode(_code.text);

    notifyListeners();
  }

  Set<String> get visibleSectionNames => _visibleSectionNames;

  set visibleSectionNames(Set<String> sectionNames) {
    _visibleSectionNames = sectionNames;
    _updateCode(_code.text);

    super.value = _getValueWithCode(_code);
  }

  /// The value with [newCode] preserving the current selection.
  ///
  /// The selection lives in the visible text, so a fold that hides the range
  /// the selection sits in truncates it to the fold marker — and the visible
  /// text alone cannot say what was truncated. Keeping the lifted selection
  /// alongside it makes folding and unfolding inverse operations on the
  /// selection, which is what routing both through here promises.
  TextEditingValue _getValueWithCode(Code newCode) {
    final fullSelection =
        _selectionHiddenByFold ??
        _code.hiddenRanges.recoverSelection(value.selection);
    final cutSelection = newCode.hiddenRanges.cutSelection(fullSelection);

    // The fold lost part of the selection exactly when lifting the truncated
    // selection back through the new ranges does not return it. Anything
    // else — a selection the fold left alone, or one the field has since
    // moved — is not remembered.
    _selectionHiddenByFold =
        newCode.hiddenRanges.recoverSelection(cutSelection) == fullSelection
        ? null
        : fullSelection;

    return TextEditingValue(text: newCode.visibleText, selection: cutSelection);
  }

  void foldCommentAtLineZero() {
    final block = _code.foldableBlocks.firstOrNull;

    if (block == null || !block.isComment || block.firstLine != 0) {
      return;
    }

    foldAt(0);
  }

  void foldImports() {
    foldBlocks(_code.foldableBlocks.where((block) => block.isImports));
  }

  /// Folds blocks that are outside all of the [names] sections.
  ///
  /// For a block to be not folded, it must overlap any of the given sections
  /// in any way.
  void foldOutsideSections(Iterable<String> names) {
    final foldLines = {..._code.foldableBlocks.map((b) => b.firstLine)};
    final sections = names
        .map((s) => _code.namedSections[s])
        .whereType<NamedSection>();

    for (final block in _code.foldableBlocks) {
      for (final section in sections) {
        if (block.overlaps(section)) {
          foldLines.remove(block.firstLine);
          break;
        }
      }
    }

    foldBlocks(
      foldLines
          .map(
            (line) => _code.foldableBlocks.firstWhereOrNull(
              (block) => block.firstLine == line,
            ),
          )
          .whereType<FoldableBlock>(),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    // IME composition (e.g. pinyin) depends on composing-aware rendering.
    // When composing is active, delegate to Flutter's default implementation
    // so the composing range is preserved and rendered correctly.
    if (hasActiveComposition) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing ?? true,
      );
    }

    final visibleSearchResult = _code.hiddenRanges.cutSearchResult(
      fullSearchResult,
    );

    // The theme is keyed as `CodeTheme.of(context)`, not as `_getTheme(context)`.
    // The latter fabricates a fresh `CodeThemeData` when no `CodeTheme` is in
    // scope, and that class implements no `==`, so keying on the fabricated
    // object would make every such call a miss — and a cache that never hits is
    // indistinguishable from no cache by anything observable.
    //
    // Navigation is keyed by `currentMatchIndex` rather than by the
    // `SearchNavigationState` object: the state implements no `==`, while the
    // controller hands out a new instance on every search-result change and on
    // every move, so identity would invalidate on things the tree never shows —
    // the total match count, the index of a match that is not current — and the
    // highlight builder reads nothing but the current index.
    final spanCacheKey = (
      code: _code,
      style: style,
      theme: CodeTheme.of(context),
      language: _language,
      searchResult: visibleSearchResult,
      currentMatchIndex: _searchNavigationController.value.currentMatchIndex,
    );

    if (spanCacheKey == _spanCacheKey) {
      return lastTextSpan = _cachedTextSpan!;
    }

    final span = SearchResultHighlightedBuilder(
      searchResult: visibleSearchResult,
      rootStyle: style,
      // Match offsets are cut against `Code.visibleText`, which carries no fold
      // marker, so the tree must not carry one either while they are being
      // sliced out of it: every marker would shift each match that follows it
      // off its own text. The panel is transient, and the marker returns the
      // moment the pattern is cleared.
      textSpan: _createTextSpan(
        context: context,
        style: style,
        withFoldEllipsis: visibleSearchResult.matches.isEmpty,
      ),
      searchNavigationState: _searchNavigationController.value,
    ).build();

    _spanCacheKey = spanCacheKey;
    _cachedTextSpan = span;
    return lastTextSpan = span;
  }

  TextSpan _createTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withFoldEllipsis = true,
  }) {
    // Return parsing
    if (_language != null) {
      return SpanBuilder(
        code: _code,
        theme: _getTheme(context),
        rootStyle: style,
        withFoldEllipsis: withFoldEllipsis,
      ).build();
    }

    return TextSpan(text: text, style: style);
  }

  CodeThemeData _getTheme(BuildContext context) {
    return CodeTheme.of(context) ?? CodeThemeData();
  }

  void dismiss() {
    _dismissSuggestions();
    _dismissSearch();
  }

  void _dismissSuggestions() {
    if (popupController.enabled) {
      popupController.hide();
    }
  }

  void _dismissSearch() {
    searchController.hideSearch(returnFocusToCodeField: true);
  }

  void showSearch() {
    searchController.showSearch();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    historyController.dispose();
    searchController.dispose();

    super.dispose();
  }
}
