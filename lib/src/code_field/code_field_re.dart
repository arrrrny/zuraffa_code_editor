import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:highlight/highlight_core.dart' as hl;
import 'package:re_editor/re_editor.dart';

import '../code_theme/code_theme_data.dart';
import '../code_theme/re_highlight_theme.dart';
import '../gutter/code_gutter.dart';
import '../line_numbers/gutter_style.dart';
import '../sizes.dart';
import '../wip/autocomplete/popup.dart';
import 'code_controller.dart';
import 'line_position_mapper.dart';
import 're_editor_controller.dart';
import 'shortcuts.dart';

/// The font size re_editor falls back to when no style is given.
const double _kDefaultFontSize = 13.0;

/// The line height multiplier re_editor falls back to when no style is given.
const double _kDefaultFontHeight = 1.4;

/// re_editor-backed code field.
///
/// Renders the controller's *visible* text (the text with folded blocks cut
/// out) through re_editor's line-virtualized [CodeEditor], and writes the
/// user's edits back into the [CodeController], which owns folding, the full
/// text, autocomplete and history.
///
/// The bridge is text-based: re_editor reports the new visible text, and the
/// controller's own diff maps that back onto the full text, so a fold's
/// hidden lines survive an edit.
class CodeFieldRe extends StatefulWidget {
  const CodeFieldRe({
    super.key,
    required this.controller,
    this.lineController,
    this.onChanged,
    this.language,
    this.theme,
    this.gutterStyle,
    this.textStyle,
    this.background,
    this.padding,
    this.cursorColor,
    this.readOnly = false,
    this.wordWrap = false,
    this.focusNode,
    this.onTap,
    this.enabled = true,
    this.autofocus = false,
  });

  /// The controller that owns the document, its folds and its history.
  final CodeController controller;

  /// The re_editor-side controller. Created from [controller]'s text when null.
  final ReEditorCodeController? lineController;

  /// Called after the document text changes.
  final ValueChanged<String>? onChanged;

  /// The language the code is highlighted with.
  ///
  /// Null highlights the code as plain text.
  final hl.Mode? language;

  /// The theme the highlighted code is styled with.
  final CodeThemeData? theme;

  /// The style of the gutter.
  ///
  /// Null shows no gutter at all.
  final GutterStyle? gutterStyle;

  /// The style of the code.
  ///
  /// The font family, the font size, the line height and the color are taken
  /// from it; the rest of the style has no counterpart in the editor.
  final TextStyle? textStyle;

  /// The background of the editor.
  final Color? background;

  /// The padding around the code.
  final EdgeInsetsGeometry? padding;

  /// The color of the caret.
  final Color? cursorColor;

  /// Whether the code can be edited.
  final bool readOnly;

  /// Whether a long line wraps instead of scrolling sideways.
  final bool wordWrap;

  /// The focus node of the editor.
  final FocusNode? focusNode;

  /// Called when the user touches the editor.
  final VoidCallback? onTap;

  /// Whether the editor takes input.
  final bool enabled;

  /// Whether the editor takes the focus when it is mounted.
  ///
  /// Off by default, like the text field renderer. re_editor focuses the
  /// editor on mount otherwise, which starts the cursor blink — and on mobile
  /// platforms that blink leaves a one-shot timer behind that outlives the
  /// widget, which fails any test that tears the editor down without
  /// advancing the clock.
  final bool autofocus;

  @override
  State<CodeFieldRe> createState() => _CodeFieldReState();
}

class _CodeFieldReState extends State<CodeFieldRe> {
  late ReEditorCodeController _line;
  late final bool _ownsLine;

  /// The scroll controller of the editor, read to place the autocomplete
  /// popup at the caret.
  final CodeScrollController _scroll = CodeScrollController();

  /// The find controller of the editor.
  ///
  /// re_editor highlights the matches of a find controller itself. This one is
  /// fed the *package's* search results, so the highlighted matches are the
  /// very ones the package's search panel counts and navigates — the two
  /// cannot drift apart.
  late final CodeFindController _find = CodeFindController(
    _line.lineController,
    const CodeFindValue.empty(),
  );

  /// The box of the editor, read to place the autocomplete popup at the caret.
  final GlobalKey _editorKey = GlobalKey();

  /// The box of the gutter, read to know how far the code is pushed to the
  /// right by the gutter.
  final GlobalKey _gutterKey = GlobalKey();

  /// The focus node the popup hands the focus back to.
  FocusNode? _ownFocusNode;

  /// The actions that take the package's editing semantics over from
  /// re_editor's own.
  ///
  /// re_editor binds Tab, Enter, the undo keys, the comment keys and the find
  /// key itself, and its `Shortcuts` widget sits closer to the focus node than
  /// the package's, so its binding wins and its action would run. Overriding
  /// the *action* of the intent re_editor raises keeps the key binding and
  /// gives the edit to the package's controller — the one that owns the folds,
  /// the history and the modifiers.
  Map<Type, Action<Intent>>? _overrideActionsCache;

  Map<Type, Action<Intent>> get _overrideActions {
    final cached = _overrideActionsCache;
    if (cached != null) {
      return cached;
    }
    final controller = widget.controller;
    final actions = <Type, Action<Intent>>{
      CodeShortcutIndentIntent: _ControllerAction(controller.onTabKeyAction),
      CodeShortcutOutdentIntent: _ControllerAction(controller.outdentSelection),
      CodeShortcutNewLineIntent: _ControllerAction(controller.onEnterKeyAction),
      CodeShortcutUndoIntent: _ControllerAction(
        controller.historyController.undo,
      ),
      CodeShortcutRedoIntent: _ControllerAction(
        controller.historyController.redo,
      ),
      CodeShortcutCommentIntent: _ControllerAction(
        controller.commentOutOrUncommentSelection,
      ),
      CodeShortcutFindIntent: _ControllerAction(controller.showSearch),
      // The editor copies what is on the screen, the package copies what the
      // document holds: the lines a fold hides are copied with it.
      CodeShortcutCopyIntent: _ControllerAction(
        () => unawaited(controller.copySelection()),
      ),
      CodeShortcutCutIntent: _ControllerAction(
        () => unawaited(controller.cutSelection()),
      ),
    };
    _overrideActionsCache = actions;
    return actions;
  }

  FocusNode get _popupFocusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  /// The overlay entry of the autocomplete popup.
  OverlayEntry? _popupEntry;

  /// The window coordinates of the popup's top-left corner, below the caret.
  Offset _normalPopupOffset = Offset.zero;

  /// The window coordinates of the popup's top-left corner, above the caret.
  Offset _flippedPopupOffset = Offset.zero;

  /// True while a change is being pushed between the two controllers, so the
  /// write does not bounce back as a new edit.
  bool _syncing = false;

  /// Whether the framework is building or laying out right now.
  ///
  /// Writing to the controller notifies its listeners, and a listener that
  /// rebuilds — a host's `ListenableBuilder`, say — cannot be rebuilt while
  /// the framework is building.
  bool get _isBuilding =>
      SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks;

  @override
  void initState() {
    super.initState();
    // The editor highlights the code itself, so the package's own highlight
    // is not needed — and its parse is quadratic in the document's length,
    // which is what makes a large document unusable. The setting is left off
    // rather than restored on dispose: a field that replaces this one with a
    // text field renderer turns it back on, and the two must not fight over
    // it.
    widget.controller.setHighlightEnabledSilently(false);
    final provided = widget.lineController;
    _ownsLine = provided == null;
    _line =
        provided ?? ReEditorCodeController(text: widget.controller.code.text);
    _line.addListener(_onLineChanged);
    widget.controller.addListener(_onControllerChanged);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    final search = widget.controller.searchController;
    search.addListener(_onSearchStateChanged);
    search.settingsController.addListener(_updateFindMatches);
    search.navigationController.addListener(_updateFindMatches);
    _pushVisibleText();
  }

  @override
  void dispose() {
    _line.removeListener(_onLineChanged);
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.popupController.removeListener(_onPopupStateChanged);
    final search = widget.controller.searchController;
    search.removeListener(_onSearchStateChanged);
    search.settingsController.removeListener(_updateFindMatches);
    search.navigationController.removeListener(_updateFindMatches);
    _popupEntry?.remove();
    _popupEntry = null;
    _ownFocusNode?.dispose();
    _find.dispose();
    _scroll.dispose();
    if (_ownsLine) {
      _line.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeFieldRe oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      // Tear down listeners on the old controller.
      oldWidget.controller.removeListener(_onControllerChanged);
      oldWidget.controller.popupController.removeListener(_onPopupStateChanged);
      final oldSearch = oldWidget.controller.searchController;
      oldSearch.removeListener(_onSearchStateChanged);
      oldSearch.settingsController.removeListener(_updateFindMatches);
      oldSearch.navigationController.removeListener(_updateFindMatches);

      // The new controller must not run the package's quadratic highlight.
      widget.controller.setHighlightEnabledSilently(false);

      // Recreate the re_editor-side controller when this state owns it.
      if (_ownsLine) {
        _line.removeListener(_onLineChanged);
        _line.dispose();
        _line = ReEditorCodeController(text: widget.controller.code.text);
        _line.addListener(_onLineChanged);
      }

      // Re-attach listeners to the new controller.
      widget.controller.addListener(_onControllerChanged);
      widget.controller.popupController.addListener(_onPopupStateChanged);
      final search = widget.controller.searchController;
      search.addListener(_onSearchStateChanged);
      search.settingsController.addListener(_updateFindMatches);
      search.navigationController.addListener(_updateFindMatches);

      // Invalidate the memoised actions: they close over the old controller.
      _overrideActionsCache = null;

      _pushVisibleText();
      _updateFindMatches();
    }

    // A provided re_editor controller was swapped in.
    if (oldWidget.lineController != widget.lineController &&
        !_ownsLine &&
        widget.lineController != null) {
      _line.removeListener(_onLineChanged);
      _line = widget.lineController!;
      _line.addListener(_onLineChanged);
      _pushVisibleText();
    }
  }

  /// The controller changed (a fold, an external write, an undo): re-render
  /// the visible text.
  void _onControllerChanged() {
    _pushVisibleText();
    _updateFindMatches();
  }

  /// The search panel was opened or closed.
  void _onSearchStateChanged() {
    _updateFindMatches();
  }

  /// Feeds the package's search results into the editor's find controller.
  ///
  /// The matches are the ones the package's own search engine found in the
  /// *visible* text — the text the editor actually shows — so a folded block
  /// cannot shift a match off the text it belongs to. They are handed over as
  /// line/column pairs, which is how re_editor addresses text.
  void _updateFindMatches() {
    final search = widget.controller.searchController;
    final settings = search.settingsController.value;
    if (!search.shouldShow || settings.pattern.isEmpty) {
      _find.value = const CodeFindValue.empty();
      return;
    }

    final visible = widget.controller.text;
    final option = CodeFindOption(
      pattern: settings.pattern,
      caseSensitive: settings.isCaseSensitive,
      regex: settings.isRegExp,
    );
    final result = search.searchText(visible, settings: settings);
    final mapper = LinePositionMapper(visible);
    final matches = <CodeLineSelection>[];
    for (final match in result.matches) {
      final start = mapper.resolve(match.start);
      final end = mapper.resolve(match.end);
      matches.add(
        CodeLineSelection(
          baseIndex: start.line,
          baseOffset: start.column,
          extentIndex: end.line,
          extentOffset: end.column,
        ),
      );
    }

    final current = search.navigationController.value.currentMatchIndex ?? -1;
    _find.value = CodeFindValue(
      option: option,
      replaceMode: false,
      result: CodeFindResult(
        index: current >= 0 && current < matches.length ? current : -1,
        matches: matches,
        option: option,
        codeLines: _line.lineController.codeLines,
        dirty: false,
      ),
    );
  }

  /// The user edited in re_editor: write the new visible text back.
  void _onLineChanged() {
    if (_syncing) {
      return;
    }
    if (_isBuilding) {
      // The editor notifies while it is being built — it hands its delegate
      // over in its `initState` — and writing to the controller notifies the
      // controller's listeners, and a listener that rebuilds cannot be
      // rebuilt while the framework is building. The write waits for the
      // frame; the state it writes is the state of the frame that follows
      // anyway.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onLineChanged();
        }
      });
      return;
    }
    _syncing = true;
    try {
      final text = _line.text;
      final mapper = LinePositionMapper(text);
      final selection = _line.lineController.selection;
      final base = mapper.toOffset(selection.baseIndex, selection.baseOffset);
      final extent = mapper.toOffset(
        selection.extentIndex,
        selection.extentOffset,
      );
      final textChanged = text != widget.controller.code.visibleText;
      if (textChanged) {
        widget.controller.value = TextEditingValue(
          text: text,
          selection: TextSelection(baseOffset: base, extentOffset: extent),
        );
        widget.onChanged?.call(widget.controller.code.text);
      } else if (widget.controller.selection !=
          TextSelection(baseOffset: base, extentOffset: extent)) {
        // A caret move on its own: the text is unchanged, but the controller
        // has to know where the caret is, or its undo stack, its current-line
        // tint and its autocomplete all work off a stale position.
        widget.controller.selection = TextSelection(
          baseOffset: base,
          extentOffset: extent,
        );
      }
    } finally {
      _syncing = false;
    }
  }

  /// Pushes the controller's visible text into the re_editor controller.
  void _pushVisibleText() {
    if (_syncing) {
      return;
    }
    _syncing = true;
    try {
      // The controller's *value* text is the visible text — the text with the
      // folded blocks cut out. `code.visibleText` lags behind on a fold: the
      // controller notifies while it assigns the new value, before it swaps in
      // the new `Code`.
      final visible = widget.controller.text;
      if (_line.text != visible) {
        _line.text = visible;
      }
      _pushSelection(visible);
    } finally {
      _syncing = false;
    }
  }

  /// Pushes the controller's caret into the re_editor controller.
  ///
  /// The re editor needs a caret it can turn into a position, and a caret of
  /// -1 — which is what a programmatic write leaves behind — has none. The
  /// offsets are the ones of the *visible* text, so they are mapped back
  /// through the visible text's own line map.
  void _pushSelection(String visible) {
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      return;
    }
    final mapper = LinePositionMapper(visible);
    final base = mapper.resolve(selection.baseOffset);
    final extent = mapper.resolve(selection.extentOffset);
    _line.lineController.selection = CodeLineSelection(
      baseIndex: base.line,
      baseOffset: base.column,
      extentIndex: extent.line,
      extentOffset: extent.column,
    );
  }

  /// Shows or hides the autocomplete popup, and keeps it at the caret.
  void _onPopupStateChanged() {
    final shouldShow = widget.controller.popupController.shouldShow;
    if (!shouldShow) {
      _popupEntry?.remove();
      _popupEntry = null;
      return;
    }

    _updatePopupOffsets();
    if (_popupEntry == null) {
      _popupEntry = OverlayEntry(builder: _buildPopup);
      Overlay.of(context).insert(_popupEntry!);
    } else {
      _popupEntry!.markNeedsBuild();
    }
  }

  /// Places the popup at the caret.
  ///
  /// The caret is measured with a [TextPainter] over the visible text, using
  /// the same style the editor lays the code out with, so the horizontal
  /// offset is the one the caret really has. The vertical offset follows from
  /// the same painter, and the editor's own scroll offsets move both back into
  /// the window.
  void _updatePopupOffsets() {
    final box = _editorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      return;
    }

    // Only the text up to the caret is needed to locate it: laying out
    // the whole visible document on every popup update is O(n) in the
    // document's length.
    final caretText = text.substring(
      0,
      (selection.baseOffset + 1).clamp(0, text.length),
    );
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: caretText, style: _codeStyle),
    )..layout();
    final caret = painter.getOffsetForCaret(selection.base, Rect.zero);
    final caretHeight = painter.getFullHeightForCaret(
      selection.base,
      Rect.zero,
    );
    painter.dispose();

    // The code starts after the gutter and the editor's own padding, and
    // scrolls with the content.
    final gutterBox = _gutterKey.currentContext?.findRenderObject();
    final gutterWidth = gutterBox is RenderBox ? gutterBox.size.width : 0.0;
    final padding =
        widget.padding?.resolve(TextDirection.ltr) ?? EdgeInsets.zero;
    final left = math.max(
      origin.dx +
          gutterWidth +
          padding.left +
          caret.dx -
          _scroll.horizontalScroller.offset,
      0.0,
    );
    final top = math.max(
      origin.dy +
          padding.top +
          caret.dy +
          caretHeight +
          16 -
          _scroll.verticalScroller.offset,
      0.0,
    );

    _normalPopupOffset = Offset(left, top);
    _flippedPopupOffset = Offset(
      left,
      top -
          (Sizes.autocompletePopupMaxHeight + caretHeight + Sizes.caretPadding),
    );
  }

  /// The style the editor lays the code out with.
  ///
  /// It has to match the editor's own style exactly, or the measured caret
  /// sits at a different place than the drawn one.
  TextStyle get _codeStyle => TextStyle(
    fontSize: widget.textStyle?.fontSize ?? _kDefaultFontSize,
    fontFamily: widget.textStyle?.fontFamily ?? 'monospace',
    fontFamilyFallback: widget.textStyle?.fontFamilyFallback,
    height: widget.textStyle?.height ?? _kDefaultFontHeight,
    color: widget.textStyle?.color,
  );

  Widget _buildPopup(BuildContext context) {
    return Popup(
      normalOffset: _normalPopupOffset,
      flippedOffset: _flippedPopupOffset,
      controller: widget.controller.popupController,
      editingWindowSize: MediaQuery.sizeOf(context),
      parentFocusNode: _popupFocusNode,
      style: _codeStyle,
      backgroundColor: widget.background,
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language ?? widget.controller.language;
    final gutterStyle = widget.gutterStyle;
    final textStyle = widget.textStyle;

    final editor = CodeEditor(
      controller: _line.lineController,
      scrollController: _scroll,
      findController: _find,
      readOnly:
          widget.readOnly || widget.controller.readOnly || !widget.enabled,
      wordWrap: widget.wordWrap,
      padding: widget.padding,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      shortcutOverrideActions: _overrideActions,
      indicatorBuilder: gutterStyle == null
          ? null
          : (context, editingController, chunkController, notifier) =>
                CodeGutter(
                  key: _gutterKey,
                  codeController: widget.controller,
                  notifier: notifier,
                  style: gutterStyle,
                  codeTextStyle: textStyle ?? const TextStyle(fontSize: 13),
                ),
      style: CodeEditorStyle(
        fontFamily: textStyle?.fontFamily ?? 'monospace',
        fontFamilyFallback: textStyle?.fontFamilyFallback,
        fontSize: textStyle?.fontSize ?? _kDefaultFontSize,
        fontHeight: textStyle?.height,
        textColor: textStyle?.color,
        backgroundColor: widget.background,
        cursorColor: widget.cursorColor,
        cursorLineColor: widget.controller.currentLineColor,
        codeTheme: language == null
            ? null
            : buildReHighlightTheme(language: language, theme: widget.theme),
      ),
    );

    final onTap = widget.onTap;
    final Widget child = onTap == null
        ? editor
        // A listener, not a gesture detector: the editor's own tap recognizers
        // sit deeper in the tree and win the arena, so a detector wrapped
        // around them would be handed nothing at all.
        : Listener(onPointerDown: (_) => onTap(), child: editor);

    return KeyedSubtree(
      key: _editorKey,
      child: Shortcuts(
        shortcuts: codeFieldShortcuts,
        child: Actions(actions: widget.controller.actions, child: child),
      ),
    );
  }
}

/// An action that runs a package-side edit.
///
/// re_editor dispatches its own intents by type, so the action has to accept
/// any intent; what it runs is fixed at construction.
class _ControllerAction extends Action<Intent> {
  final void Function() _run;

  _ControllerAction(this._run);

  @override
  Object? invoke(Intent intent) {
    _run();
    return null;
  }
}
