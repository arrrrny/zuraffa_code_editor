import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../gutter/gutter.dart';
import '../line_numbers/gutter_style.dart';
import '../search/widget/search_widget.dart';
import '../sizes.dart';
import '../wip/autocomplete/popup.dart';
import 'actions/comment_uncomment.dart';
import 'actions/enter_key.dart';
import 'actions/indent.dart';
import 'actions/outdent.dart';
import 'actions/search.dart';
import 'actions/tab.dart';
import 'code_controller.dart';
import 'default_styles.dart';
import 'js_workarounds/js_workarounds.dart';

final _shortcuts = <ShortcutActivator, Intent>{
  // Copy
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC):
      CopySelectionTextIntent.copy,
  const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
      CopySelectionTextIntent.copy,
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.insert):
      CopySelectionTextIntent.copy,

  // Cut
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX):
      const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  const SingleActivator(LogicalKeyboardKey.keyX, meta: true):
      const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.delete):
      const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),

  // Undo
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
      const UndoTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
      const UndoTextIntent(SelectionChangedCause.keyboard),

  // Redo
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(
    SelectionChangedCause.keyboard,
  ),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(
    SelectionChangedCause.keyboard,
  ),

  // Indent
  LogicalKeySet(LogicalKeyboardKey.tab): const IndentIntent(),

  // Outdent
  LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
      const OutdentIntent(),

  // Comment Uncomment
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.slash):
      const CommentUncommentIntent(),
  const SingleActivator(LogicalKeyboardKey.slash, meta: true):
      const CommentUncommentIntent(),

  // Search
  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
      const SearchIntent(),
  const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
      const SearchIntent(),
};

// Shortcuts that must not fire while an IME composition is in progress,
// as they would either drop the composition or act on the composing text.
final _shortcutsIgnoredWhileComposing = <ShortcutActivator, Intent>{
  // Dismiss
  LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),

  // EnterKey
  LogicalKeySet(LogicalKeyboardKey.enter): const EnterKeyIntent(),

  // TabKey
  LogicalKeySet(LogicalKeyboardKey.tab): const TabKeyIntent(),
};

/// The vertical insets both the editor's `TextField` (`contentPadding`, set
/// below) and the gutter's outer `Padding` carry: 16 on each edge. They are
/// the same, so when comparing the two scroll extents they cancel and only
/// the row heights are left to disagree.
const _contentInsets = 32.0;

class CodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around
  /// or make the field scrollable horizontally.
  final bool wrap;

  /// A CodeController instance to apply
  /// language highlight, themeing and modifiers.
  final CodeController controller;

  /// An UndoHistoryController instance
  /// to control TextField history.
  final UndoHistoryController? undoController;

  @Deprecated('Use gutterStyle instead')
  final GutterStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// {@macro flutter.widgets.textField.smartDashesType}
  final SmartDashesType smartDashesType;

  /// {@macro flutter.widgets.textField.smartQuotesType}
  final SmartQuotesType smartQuotesType;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  ///
  /// This is just passed as a parameter to a [TextField].
  /// See also [CodeController.readOnly].
  final bool readOnly;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;

  @Deprecated('Use gutterStyle instead')
  final bool? lineNumbers;

  final GutterStyle gutterStyle;

  const CodeField({
    super.key,
    required this.controller,
    this.undoController,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.smartDashesType = SmartDashesType.disabled,
    this.smartQuotesType = SmartQuotesType.disabled,
    this.padding = EdgeInsets.zero,
    GutterStyle? gutterStyle,
    this.enabled,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    @Deprecated('Use gutterStyle instead') this.lineNumbers,
    @Deprecated('Use gutterStyle instead')
    this.lineNumberStyle = const GutterStyle(),
  }) : assert(
         gutterStyle == null || lineNumbers == null,
         'Can not provide gutterStyle and lineNumbers at the same time. '
         'Please use gutterStyle and provide necessary columns to show/hide',
       ),
       gutterStyle =
           gutterStyle ??
           ((lineNumbers == false) ? GutterStyle.none : lineNumberStyle);

  @override
  State<CodeField> createState() => _CodeFieldState();
}

/// Reads [controller.offset] but tolerates a controller that cannot answer
/// it: returns 0 unless exactly one scroll position is attached.
///
/// `ScrollController.offset` throws `ScrollController not attached to any
/// scroll views` while the field's scroll views have no position — a state the
/// popup-offset updates can observe, because
/// `CodeController.analyzeCode()` notifies from a later microtask. Upstream
/// akvelon/flutter-code-editor#275 is a crash report from exactly that path.
/// With multiple positions attached it throws
/// `offset cannot be used when multiple ScrollPositions are attached`
/// instead; this widget's controllers each wrap exactly one scroll view, and
/// any other count degrades to 0 rather than crashing the notification path.
@visibleForTesting
double scrollOffsetOrZero(ScrollController controller) {
  if (controller.positions.length != 1) {
    return 0;
  }
  return controller.offset;
}

class _CodeFieldState extends State<CodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  ScrollController? _horizontalCodeScroll;
  final _codeFieldKey = GlobalKey();

  OverlayEntry? _suggestionsPopup;
  OverlayEntry? _searchPopup;
  Offset _normalPopupOffset = Offset.zero;
  Offset _flippedPopupOffset = Offset.zero;
  double painterWidth = 0;
  double painterHeight = 0;

  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';
  Size? windowSize;
  late TextStyle textStyle;
  Color? _backgroundCol;

  final _editorKey = GlobalKey();
  Offset? _editorOffset;

  /// Width the editor's text is laid out at, taken from its own
  /// `LayoutBuilder`. Only used to measure wrapped gutter rows.
  double? _editorTextWidth;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(_onSearchControllerChange);
    _horizontalCodeScroll = ScrollController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.attach(context, onKeyEvent: _onKeyEvent);

    widget.controller.searchController.codeFieldFocusNode = _focusNode;

    // Workaround for disabling spellchecks in FireFox
    // https://github.com/akvelon/flutter-code-editor/issues/197
    disableSpellCheckIfWeb();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final double width = _codeFieldKey.currentContext!.size!.width;
      final double height = _codeFieldKey.currentContext!.size!.height;
      windowSize = Size(width, height);
    });
    _onTextChanged();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.searchController.codeFieldFocusNode = null;
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_updatePopupOffset);
    widget.controller.popupController.removeListener(_onPopupStateChanged);
    _suggestionsPopup?.remove();
    widget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );
    _searchPopup?.remove();
    _searchPopup = null;
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _horizontalCodeScroll?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_onTextChanged);
    oldWidget.controller.removeListener(_updatePopupOffset);
    oldWidget.controller.popupController.removeListener(_onPopupStateChanged);
    oldWidget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );

    widget.controller.searchController.codeFieldFocusNode = _focusNode;
    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(_onSearchControllerChange);
  }

  /// The old `_codeScroll != null` half of this guard was dead weight:
  /// `_codeScroll` and `_horizontalCodeScroll` are assigned unconditionally in
  /// [initState] and only listeners attached after that can fire, so a
  /// laid-out editor box implies both are non-null for the `!` unwraps in
  /// `_onTextChanged`, `_getPopupLeftOffset` and `_getPopupTopOffset`.
  bool get _isEditorBoxLaidOut {
    final box = _editorKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize;
  }

  void rebuild() {
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        // For some reason _codeFieldKey.currentContext is null in tests
        // so check first.
        final context = _codeFieldKey.currentContext;
        if (context != null) {
          final double width = context.size!.width;
          final double height = context.size!.height;
          windowSize = Size(width, height);
        }
      });
    });
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    if (_isEditorBoxLaidOut) {
      final box = _editorKey.currentContext!.findRenderObject() as RenderBox;
      _editorOffset = box.localToGlobal(Offset.zero);
      if (_editorOffset != null) {
        var fixedOffset = _editorOffset!;
        fixedOffset += Offset(0, scrollOffsetOrZero(_codeScroll!));
        _editorOffset = fixedOffset;
      }

      // While the editor box has no size the frame is still being built or
      // laid out (e.g. an analyzeCode() notification landing there): both the
      // offset read above and setState below would throw.
      rebuild();
    }
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
    double maxHeight,
  ) {
    if (widget.wrap) {
      // Soft wrapping needs the field to be width-bounded: an `IntrinsicWidth`
      // (below) sizes the field to its longest line instead, so the text never
      // reflows and just scrolls horizontally, whatever the flag says.
      return Padding(
        padding: EdgeInsets.only(right: widget.padding.right),
        child: widget.expands
            ? codeField
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: codeField,
              ),
      );
    }

    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 0, minWidth: minWidth),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          // The field must know how tall the viewport is: a TextField with
          // maxLines: null grows to its content height, so left unbounded the
          // column overflows instead of scrolling and the caret scrolls out
          // of view. Bounding it by the editor box height keeps the field's
          // own vertical scrollable (and the linked gutter) in charge, which
          // also restores Flutter's auto-reveal-the-caret-while-typing.
          widget.expands
              ? Expanded(child: codeField)
              : ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: codeField,
                ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(right: widget.padding.right),
      scrollDirection: Axis.horizontal,
      controller: _horizontalCodeScroll,
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';

    final themeData = Theme.of(context);
    final styles = CodeTheme.of(context)?.styles;
    _backgroundCol =
        widget.background ??
        styles?[rootKey]?.backgroundColor ??
        DefaultStyles.backgroundColor;

    if (widget.decoration != null) {
      _backgroundCol = null;
    }

    final defaultTextStyle = TextStyle(
      color: styles?[rootKey]?.color ?? DefaultStyles.textColor,
      fontSize: themeData.textTheme.titleMedium?.fontSize,
      height: themeData.textTheme.titleMedium?.height,
    );

    textStyle = defaultTextStyle.merge(widget.textStyle);

    final isComposingText = widget.controller.hasActiveComposition;
    final shortcuts = {
      ..._shortcuts,
      if (!isComposingText) ..._shortcutsIgnoredWhileComposing,
    };

    final codeField = TextField(
      focusNode: _focusNode,
      scrollPadding: widget.padding,
      style: textStyle,
      smartDashesType: widget.smartDashesType,
      smartQuotesType: widget.smartQuotesType,
      controller: widget.controller,
      undoController: widget.undoController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      decoration: const InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: 16),
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      cursorColor: widget.cursorColor ?? defaultTextStyle.color,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
    );

    final editingField = Theme(
      data: Theme.of(
        context,
      ).copyWith(textSelectionTheme: widget.textSelectionTheme),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // The gutter is laid out before the editor in the same build pass,
          // so it can only see a width measured in an earlier frame. Keep the
          // measured one and rebuild after this frame so the gutter's wrapped
          // rows follow the field's real width.
          final textWidth = constraints.maxWidth - widget.padding.right;
          if (widget.wrap && textWidth > 0 && textWidth != _editorTextWidth) {
            _editorTextWidth = textWidth;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && textWidth == _editorTextWidth) {
                setState(() {});
              }
            });
          }

          // Control horizontal scrolling
          return _wrapInScrollView(
            codeField,
            textStyle,
            constraints.maxWidth,
            constraints.maxHeight,
          );
        },
      ),
    );

    return FocusableActionDetector(
      actions: widget.controller.actions,
      shortcuts: shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: _backgroundCol,
        key: _codeFieldKey,
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.gutterStyle.showGutter) _buildGutter(),
            Expanded(key: _editorKey, child: editingField),
          ],
        ),
      ),
    );
  }

  Widget _buildGutter() {
    final lineNumberSize = textStyle.fontSize;
    final lineNumberColor =
        widget.gutterStyle.textStyle?.color ??
        textStyle.color?.withValues(alpha: .5);

    final lineNumberTextStyle = (widget.gutterStyle.textStyle ?? textStyle)
        .copyWith(
          color: lineNumberColor,
          fontFamily: textStyle.fontFamily,
          fontSize: lineNumberSize,
          // The gutter's line boxes must be exactly as tall as the code's.
          // fontSize/fontFamily are already overridden for that reason, but
          // without height each gutter row falls back to the font's own metrics
          // and so has a different height than the text line it labels. The two
          // grids then drift apart by that difference on every line, which is
          // catastrophic once a few blocks are collapsed.
          height: textStyle.height,
        );

    final gutterStyle = widget.gutterStyle.copyWith(
      textStyle: lineNumberTextStyle,
      errorPopupTextStyle:
          widget.gutterStyle.errorPopupTextStyle ??
          CodeTheme.of(context)?.styles['root'] ??
          textStyle.copyWith(
            fontSize: DefaultStyles.errorPopupTextSize,
            backgroundColor: DefaultStyles.backgroundColor,
            fontStyle: DefaultStyles.fontStyle,
          ),
    );

    return GutterWidget(
      codeController: widget.controller,
      style: gutterStyle,
      scrollController: _numberScroll,
      rowHeights: _wrappedRowHeights(textStyle),
    );
  }

  /// Height each visible code line renders at, or null when the editor does
  /// not wrap (where every row is one line high and the shared style already
  /// pins it).
  ///
  /// Wrapping is the one case the gutter has to be told about: a wrapped
  /// logical line occupies several visual rows, so with the rows left at
  /// one line high the gutter's scroll extent stops matching the code's and
  /// the numbers drift off their lines. The width comes from the editor's own
  /// `LayoutBuilder`, so the measurement mirrors the field's layout.
  List<double>? _wrappedRowHeights(TextStyle codeTextStyle) {
    final textWidth = _editorTextWidth;
    if (!widget.wrap || textWidth == null) {
      return null;
    }

    var rows = _measureWrappedRows(codeTextStyle, textWidth);
    final excess = _gutterRowExcess(rows);
    if (excess.abs() < 0.5 || _codePosition == null) {
      return rows;
    }

    // The editor reserves a few logical pixels of its own insets that the
    // `LayoutBuilder` width knows nothing about, so the measured rows can
    // fall either side of the field's real wrapping and the two scroll views
    // disagree about how long the content is. Search the adjacent widths —
    // the gutter is fixed width, so this never feeds back into the layout —
    // and keep the set of rows that makes the heights agree again.
    var best = rows;
    var bestExcess = excess;
    var low = textWidth - 24;
    var high = textWidth;

    for (var attempt = 0; attempt < 8; attempt++) {
      final mid = (low + high) / 2;
      if (mid <= 0) {
        break;
      }
      final candidate = _measureWrappedRows(codeTextStyle, mid);
      final delta = _gutterRowExcess(candidate);
      if (delta.abs() < bestExcess.abs()) {
        best = candidate;
        bestExcess = delta;
      }
      if (delta.abs() < 0.5) {
        break;
      }
      if (delta.sign == excess.sign) {
        high = mid;
      } else {
        low = mid;
      }
    }

    return best;
  }

  /// The code scrollable's position, when exactly one is attached.
  ScrollPosition? get _codePosition {
    if (_codeScroll == null || _codeScroll!.positions.length != 1) {
      return null;
    }
    return _codeScroll!.position;
  }

  /// How much taller (positive) or shorter (negative) the visible rows are
  /// than the editor's own text.
  ///
  /// Both scroll views carry the same 32 logical pixels of vertical insets
  /// (the editor's `contentPadding`, the gutter's outer `Padding`), so those
  /// cancel and only the rows are left to disagree.
  double _gutterRowExcess(List<double> rows) {
    final code = _codePosition;
    if (code == null || !code.hasContentDimensions) {
      return 0;
    }

    final rowSum = rows.fold<double>(0, (sum, row) => sum + row);
    final codeTextHeight =
        code.maxScrollExtent + code.viewportDimension - _contentInsets;

    return rowSum - codeTextHeight;
  }

  List<double> _measureWrappedRows(TextStyle style, double textWidth) {
    final visibleLines = widget
        .controller
        .code
        .hiddenLineRanges
        .visibleLineNumbers
        .toList();
    // A degenerate style can lay a line out at zero height; the row must
    // never collapse below a real line or the gutter would grind against it.
    final minRowHeight = _singleLineHeight(style);

    return List.generate(visibleLines.length, (row) {
      final line = _withoutLineBreak(
        widget.controller.code.lines[visibleLines[row]].text,
      );
      final measured = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: line, style: style),
      )..layout(maxWidth: textWidth);

      final height = measured.height;
      measured.dispose();
      return max(height, minRowHeight);
    });
  }

  /// [CodeLine.text] keeps its trailing line break; measuring one with it
  /// laid out as a paragraph yields two rows for every line.
  String _withoutLineBreak(String line) {
    if (line.endsWith('\n')) {
      line = line.substring(0, line.length - 1);
    }
    if (line.endsWith('\r')) {
      line = line.substring(0, line.length - 1);
    }
    return line;
  }

  double _singleLineHeight(TextStyle style) {
    final measured = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: '', style: style),
    )..layout();
    final height = measured.height;
    measured.dispose();
    return height;
  }

  void _updatePopupOffset() {
    if (!_isEditorBoxLaidOut) {
      // Same mid-frame window as in _onTextChanged: without a laid-out editor
      // box the offsets cannot be positioned and setState would throw.
      return;
    }

    final textPainter = _getTextPainter(widget.controller.text);
    final caretHeight = _getCaretHeight(textPainter);

    final leftOffset = _getPopupLeftOffset(textPainter);
    final normalTopOffset = _getPopupTopOffset(textPainter, caretHeight);
    final flippedTopOffset =
        normalTopOffset -
        (Sizes.autocompletePopupMaxHeight + caretHeight + Sizes.caretPadding);

    setState(() {
      _normalPopupOffset = Offset(leftOffset, normalTopOffset);
      _flippedPopupOffset = Offset(leftOffset, flippedTopOffset);
    });
  }

  TextPainter _getTextPainter(String text) {
    return TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: textStyle),
    )..layout();
  }

  Offset _getCaretOffset(TextPainter textPainter) {
    return textPainter.getOffsetForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
  }

  double _getCaretHeight(TextPainter textPainter) {
    final double caretFullHeight = textPainter.getFullHeightForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
    return caretFullHeight;
  }

  double _getPopupLeftOffset(TextPainter textPainter) {
    return max(
      _getCaretOffset(textPainter).dx +
          widget.padding.left -
          scrollOffsetOrZero(_horizontalCodeScroll!) +
          (_editorOffset?.dx ?? 0),
      0,
    );
  }

  double _getPopupTopOffset(TextPainter textPainter, double caretHeight) {
    return max(
      _getCaretOffset(textPainter).dy +
          caretHeight +
          16 +
          widget.padding.top -
          scrollOffsetOrZero(_codeScroll!) +
          (_editorOffset?.dy ?? 0),
      0,
    );
  }

  void _onPopupStateChanged() {
    final shouldShow =
        widget.controller.popupController.shouldShow && windowSize != null;
    if (!shouldShow) {
      _suggestionsPopup?.remove();
      _suggestionsPopup = null;
      return;
    }

    if (_suggestionsPopup == null) {
      _suggestionsPopup = _buildSuggestionOverlay();
      Overlay.of(context).insert(_suggestionsPopup!);
    }

    _suggestionsPopup!.markNeedsBuild();
  }

  void _onSearchControllerChange() {
    final shouldShow = widget.controller.searchController.shouldShow;

    if (!shouldShow) {
      _searchPopup?.remove();
      _searchPopup = null;
      return;
    }

    if (_searchPopup == null) {
      _searchPopup = _buildSearchOverlay();
      Overlay.of(context).insert(_searchPopup!);
    }
  }

  OverlayEntry _buildSearchOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = _getTextColorFromTheme() ?? colorScheme.onSurface;
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
            child: Material(
              child: SearchWidget(
                searchController: widget.controller.searchController,
              ),
            ),
          ),
        );
      },
    );
  }

  Color? _getTextColorFromTheme() {
    final textTheme = Theme.of(context).textTheme;

    return textTheme.bodyLarge?.color ??
        textTheme.bodyMedium?.color ??
        textTheme.bodySmall?.color ??
        textTheme.displayLarge?.color ??
        textTheme.displayMedium?.color ??
        textTheme.displaySmall?.color ??
        textTheme.headlineLarge?.color ??
        textTheme.headlineMedium?.color ??
        textTheme.headlineSmall?.color ??
        textTheme.labelLarge?.color ??
        textTheme.labelMedium?.color ??
        textTheme.labelSmall?.color ??
        textTheme.titleLarge?.color ??
        textTheme.titleMedium?.color ??
        textTheme.titleSmall?.color;
  }

  OverlayEntry _buildSuggestionOverlay() {
    return OverlayEntry(
      builder: (context) {
        return Popup(
          normalOffset: _normalPopupOffset,
          flippedOffset: _flippedPopupOffset,
          controller: widget.controller.popupController,
          editingWindowSize: windowSize!,
          style: textStyle,
          backgroundColor: _backgroundCol,
          parentFocusNode: _focusNode!,
          editorOffset: _editorOffset,
        );
      },
    );
  }
}
