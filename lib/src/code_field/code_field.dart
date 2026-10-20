import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'actions/overtype.dart';
import 'actions/page_scroll.dart';
import 'actions/search.dart';
import 'actions/tab.dart';
import 'code_controller.dart';
import 'default_styles.dart';
import 'js_workarounds/js_workarounds.dart';
import 'line_background.dart';

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

  // Page Up / Down: scroll the editor by one viewport
  const SingleActivator(LogicalKeyboardKey.pageDown): const PageScrollIntent(
    forward: true,
  ),
  const SingleActivator(LogicalKeyboardKey.pageUp): const PageScrollIntent(
    forward: false,
  ),
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

  // Overtype: bare Insert. Flutter has no overtype hook
  // (flutter/flutter#122673) and `DefaultTextEditingShortcuts` binds only
  // Ctrl-Insert (copy) and Shift-Insert (paste), so the bare key reaches here.
  // A SingleActivator with no modifiers does not match a modified Insert, so
  // the copy binding above keeps working. Ignored while composing for the same
  // reason as Enter and Tab: the keystroke belongs to the IME.
  const SingleActivator(LogicalKeyboardKey.insert):
      const ToggleOvertypeIntent(),
};

/// The vertical insets both the editor's `TextField` (`contentPadding`, set
/// below) and the gutter's outer `Padding` carry — two edges of
/// [codeFieldVerticalPadding]. Reading both paddings from that one constant
/// keeps them from drifting apart, which would leave the gutter comparison in
/// `_CodeFieldState._gutterRowExcess` unable to ever match.
const _contentInsets = 2 * codeFieldVerticalPadding;

/// What the toolbar looks like when the app set no `contextMenuBuilder`.
///
/// `TextField` declares the parameter nullable but defaults it to a private
/// `_defaultContextMenuBuilder`, and that default is reachable only by leaving
/// the argument out: an explicit null disables the selection toolbar outright,
/// so Copy / Select All would vanish from every `CodeField`. Reading the
/// default off a bare `TextField` gets the real one — including its
/// `SystemContextMenu` branch on iOS — without forking Flutter's logic.
final _defaultContextMenuBuilder = const TextField().contextMenuBuilder;

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

  /// {@macro flutter.widgets.EditableText.contextMenuBuilder}
  ///
  /// The selection toolbar only: the editor's own actions (search, comment,
  /// indent) stay wired through [FocusableActionDetector] either way, so this
  /// changes what the menu looks like, not what the keyboard does.
  ///
  /// Leave it null to keep the platform default menu, or return an empty widget
  /// (for example `SizedBox.shrink()`) to suppress the menu entirely.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// The direction the editor's text is laid out and measured in.
  ///
  /// Left null the field reads the ambient [Directionality], which is what an
  /// RTL locale already installs, so Arabic text lays out right to left with no
  /// configuration at all. Set it to force one direction regardless of locale —
  /// for example to render a right-to-left snippet inside a left-to-right app.
  ///
  /// Everything the editor measures with a [TextPainter] follows the direction
  /// resolved here, not a hardcoded [TextDirection.ltr]: the caret measurement
  /// that positions the autocomplete popup would otherwise be taken against the
  /// wrong layout and place the popup on the far side of the field.
  final TextDirection? textDirection;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// Called when the user taps the editor, after the field has handled the tap.
  ///
  /// This is the hook for "the user touched the code" — focus the field, hide an
  /// overlay, log an analytics event. Wrapping the editor in a
  /// [GestureDetector] instead does **not** work and is not a substitute: the
  /// detector competes with `TextField`'s own tap recognizers, which are
  /// further down the tree, and those win the arena. The wrapper is then handed
  /// nothing at all — no error, no callback, nothing to debug.
  ///
  /// Forwarded to the field as is, so the gesture that fires this is the same
  /// one that places the caret: a tap both notifies the host and leaves the
  /// caret where it belongs. Leave it null for the default behaviour.
  final VoidCallback? onTap;

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

  /// The background colour of the autocomplete suggestion popup.
  ///
  /// Defaults to [background] (the editor's own background) when no
  /// [decoration] is given, and to the theme's card colour otherwise, so the
  /// popup is never transparent just because the field is decorated.
  final Color? autocompleteBackground;

  /// Builds one row of the autocomplete suggestion popup.
  ///
  /// When null the popup renders its built-in row. When set, it is called once
  /// per suggestion with the suggestion's text, whether that row is the
  /// selected one, and a callback that commits it — the same tap behaviour the
  /// built-in row has, including returning focus to the editor.
  ///
  /// This is the hook a host needs to put an icon, a second line or its own
  /// selection affordance on a suggestion; the popup's own placement, flip and
  /// clamping stay the package's, because that is the part positioning tests
  /// pin.
  ///
  /// The one thing the hook cannot change is **the row's height**: the popup
  /// measures each suggestion as the built-in row's single line — the ambient
  /// `bodyMedium` style merged with `style` — and decides the flip and the
  /// clamp on that. A builder that returns a taller row is laid out at its own
  /// height, so a list of them can be taller than the space the flip reserved
  /// for it and overflow either edge of the window. Keep a built row to one
  /// line, or give it the same height as one, if it has to fit.
  final Widget Function(
    BuildContext context,
    String suggestion,
    bool isSelected,
    VoidCallback onSelect,
  )?
  suggestionItemBuilder;

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
    this.autocompleteBackground,
    this.suggestionItemBuilder,
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
    this.contextMenuBuilder,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.textDirection,
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

  /// Keeps the per-line background layer aligned with the text, the same way
  /// `_numberScroll` keeps the gutter aligned.
  ScrollController? _backgroundScroll;
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

  /// The window size the suggestion popup is bounded by.
  ///
  /// The popup is inserted into the root overlay, so it is placed at window
  /// coordinates and has to stay inside the window — not inside this field's
  /// render box, which is the smaller rectangle whenever the editor is
  /// narrower than the window.
  Size? windowSize;
  late TextStyle textStyle;
  Color? _backgroundCol;

  /// The direction the field is laid out in, resolved in `build` from
  /// [CodeField.textDirection] or, when that is null, the ambient
  /// [Directionality].
  ///
  /// Only the caret measurement needs it: a caret's horizontal offset — and so
  /// the autocomplete popup that hangs off it — depends on which way the
  /// paragraph runs, while a line's height does not. That is why the row-height
  /// painters below keep laying out as [TextDirection.ltr].
  TextDirection _textDirection = TextDirection.ltr;

  /// Resolved background of the suggestion popup, recomputed in `build` from
  /// [CodeField.autocompleteBackground], then `_backgroundCol`, then the
  /// theme's card colour. Unlike `_backgroundCol` it is never null, so the
  /// popup stays opaque while the field itself is painted by a decoration.
  late Color _popupBackground;

  final _editorKey = GlobalKey();
  Offset? _editorOffset;

  /// Width the editor's text is laid out at, taken from its own
  /// `LayoutBuilder`. Only used to measure wrapped gutter rows.
  double? _editorTextWidth;

  /// The last wrapped-row measurement and the inputs it came from.
  ///
  /// Measuring the whole document is the costly half of the wrap path (one
  /// `TextPainter` per line, up to nine times with the calibration) and
  /// `_buildGutter` asks for it on every `build()`. The rows are a pure
  /// function of the controller's text and the measured width, so a rebuild
  /// that changes neither — every `setState` except a keystroke — reuses the
  /// cached list instead of re-measuring the file.
  String? _rowHeightsForText;
  double? _rowHeightsForWidth;
  List<double>? _cachedRowHeights;

  /// The controller value [_onTextChanged] last saw.
  ///
  /// The controller notifies for more than a value change — an analysis result,
  /// a search result, the suggestion popup — and only a value change can move
  /// the caret somewhere the viewport does not show, so the reveal below is
  /// driven off the comparison rather than off every notification.
  TextEditingValue _lastValue = const TextEditingValue();

  /// The text [_onTextChanged] last saw, used to skip the O(n) whole-document
  /// split and longest-line scan when only the analysis result or selection
  /// changed (no text change).
  String _lastText = '';

  /// The hidden-line ranges [_onTextChanged] last saw. Folding toggles notify
  /// with unchanged text, so this is what tells a rebuild apart from a pure
  /// analysis-result notification.
  String _lastHiddenRanges = '';

  /// Last text/selection seen by [_updatePopupOffset], to skip the whole-text
  /// TextPainter relayout when neither moved.
  String _lastPopupText = '';
  TextSelection _lastPopupSelection = const TextSelection.collapsed(offset: -1);
  TextDirection _lastPopupDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    _backgroundScroll = _controllers?.addAndGet();

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
      // The popup is inserted into the root overlay, so its bounds are the
      // window's — not this field's render box, which is often the smaller
      // rectangle (a narrow editor, a gutter, an inset pane) and would push
      // the popup off the edge.
      windowSize = MediaQuery.maybeOf(context)?.size;
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
    _backgroundScroll?.dispose();
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
        // Same reason as the initState callback: the popup lives in the root
        // overlay and is bounded by the window.
        windowSize = MediaQuery.maybeOf(context)?.size;
      });
    });
  }

  void _onTextChanged() {
    final value = widget.controller.value;
    final valueChanged = value != _lastValue;
    final textChanged = value.text != _lastText;
    final selectionChanged = value.selection != _lastValue.selection;
    final hiddenRanges = widget.controller.code.hiddenLineRanges.toString();
    final foldsChanged = hiddenRanges != _lastHiddenRanges;
    _lastValue = value;
    _lastText = value.text;
    _lastHiddenRanges = hiddenRanges;

    // Rebuild longest line only when the document text actually changed.
    // Analysis-result and search-result notifications carry the same text and
    // must not trigger an O(n) whole-document split on every notification.
    if (textChanged && !widget.wrap) {
      longestLine = '';
      for (final line in value.text.split('\n')) {
        if (line.length > longestLine.length) longestLine = line;
      }
    }

    // The offset read is cheap; keep it on every notification so popup
    // positioning and text-direction tests stay correct. Only the O(n)
    // longest-line scan above is gated on a real text change.
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

    if (valueChanged) {
      _revealCaretOnScreen();
    }
  }

  /// Reveals the caret after a value change the framework would reveal for the
  /// platform's input but not for the controller's (#149).
  ///
  /// `EditableText` runs its own reveal — `_scheduleShowCaretOnScreen` — from
  /// `userUpdateTextEditingValue`, the method every keystroke and every IME
  /// update arrives through, but deliberately not from
  /// `_didChangeTextEditingValue`, the listener a `TextEditingController`
  /// write notifies. So the same edit made by typing scrolls the caret into
  /// view and made through `CodeController.text` / `.selection` does not: the
  /// caret walks off the bottom of the viewport and the user has to find it by
  /// hand. This is that reveal, run on the controller's path.
  ///
  /// It is the framework's own reveal, not a re-measurement: the caret rect
  /// comes from the laid-out `RenderEditable` and the offset is the one
  /// `EditableText._getOffsetToRevealCaret` derives from it. Laying the text
  /// out here instead would need the field's line heights, and a second
  /// measure drifting from the render object is exactly the
  /// fighting-the-gutter problem the wrap calibration already has.
  ///
  /// Focus gates it, the same condition `EditableText._handleFocusChanged`
  /// puts on its own reveal: a host that loads a document the user has not
  /// opened yet must not have the viewport yanked to wherever the caret
  /// landed, and the reveal happens on the focus change that follows anyway.
  ///
  /// The reveal is scheduled for after the frame the new value rebuilds,
  /// because a caret rect read from the previous layout is the old caret's —
  /// and for after a microtask, because of who else reveals. The framework
  /// writes the value through `_formatAndSetValue`, which is what notifies the
  /// listener above, and only then calls `_scheduleShowCaretOnScreen`
  /// (`editable_text.dart:3726`, with a comment saying outright that
  /// programmatic changes get no reveal while user changes do). So a reveal
  /// registered from this listener is ordered *ahead* of the framework's on
  /// every keystroke, and jumping the offset it is still about to animate to
  /// would turn the typing path's animated reveal into an instant one. A
  /// microtask runs once the whole keystroke is done, which puts this reveal
  /// behind the framework's own and lets that one lead, as it does today.
  void _revealCaretOnScreen() {
    if (_focusNode!.hasFocus != true) {
      return;
    }

    scheduleMicrotask(() {
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _revealCaret();
      });
    });
  }

  /// Moves the field's offset to the caret, and only ever to it.
  ///
  /// Everything here is a condition under which moving the offset would be
  /// wrong, and each is reachable from a host: no laid-out field, a host that
  /// made the field unscrollable, an offset already on its way somewhere, and
  /// a caret that is already in view.
  void _revealCaret() {
    final selection = widget.controller.value.selection;
    if (!selection.isValid) {
      return;
    }

    final renderEditable = _renderEditable;
    final position = _codePosition;
    if (renderEditable == null || position == null) {
      return;
    }

    // The same flag `RenderObject.showOnScreen` checks before it scrolls:
    // false while a drag or a fling owns the field, or while a host has made
    // it unscrollable, and a reveal must not take the field off the user.
    if (!position.allowImplicitScrolling) {
      return;
    }

    // An offset already on its way somewhere — the framework's reveal
    // animating the caret into view on the path that carried a keystroke, or a
    // drag the user has not let go of — is not this reveal's to move. Taking
    // it over cancels whatever was driving it, and an instant jump where the
    // framework animated one is a visible difference on the typing path.
    // `isScrollingNotifier` is the public read the framework documents for
    // "is this position running an activity", rather than the `activity` it
    // backs.
    if (position.isScrollingNotifier.value) {
      return;
    }

    final caretRect = renderEditable.getLocalRectForCaret(selection.extent);
    final target = _offsetToRevealCaret(caretRect, position);

    // A caret already in the band is the ordinary case on the framework's
    // paths, and `jumpTo` would disturb the position even to move it nowhere.
    if (target == position.pixels) {
      return;
    }

    // The field is its own vertical viewport, so the offset is driven directly
    // and `showOnScreen` is what reveals the caret sideways and on any
    // scrollable the host wrapped the field in — the two halves of the
    // framework's own reveal, in the order it makes them.
    position.jumpTo(target);
    renderEditable.showOnScreen(rect: widget.padding.inflateRect(caretRect));
  }

  /// The scroll offset that brings the caret at [caretRect] into view.
  ///
  /// Both edges of the rect are read against the visible band rather than the
  /// document: `RenderEditable.getLocalRectForCaret` hands back a rect already
  /// shifted by the current paint offset. So the caret is in view exactly when
  /// it lies inside `[0, viewportDimension]`, and revealing it is the smallest
  /// move that puts it there — down by however far its bottom edge has fallen
  /// past the band's bottom, up by however far its top has drifted past the
  /// band's top. A caret already inside moves nothing.
  ///
  /// This is `EditableText._getOffsetToRevealCaret`, which the framework runs
  /// for a keystroke and not for a controller write (#149).
  double _offsetToRevealCaret(Rect caretRect, ScrollPosition position) {
    final double delta;
    if (caretRect.bottom > position.viewportDimension) {
      delta = caretRect.bottom - position.viewportDimension;
    } else if (caretRect.top < 0) {
      delta = caretRect.top;
    } else {
      return position.pixels;
    }

    final target = position.pixels + delta;
    return min(max(target, position.minScrollExtent), position.maxScrollExtent);
  }

  /// The [RenderEditable] the field's text is painted by, or null while the
  /// field is not laid out.
  ///
  /// No key in this package reaches it. `EditableText` builds its render object
  /// several proxies below the editor box — the field's own `Scrollable`, the
  /// semantics and mouse regions around the text — and none of those proxies
  /// is a widget this package supplies, so the editor box is searched for it
  /// instead. The search is bounded by the field's subtree and the field holds
  /// exactly one `TextField`, so the first match is the field's own.
  RenderEditable? get _renderEditable {
    final root = _editorKey.currentContext?.findRenderObject();
    return root == null ? null : _findRenderEditable(root);
  }

  static RenderEditable? _findRenderEditable(RenderObject root) {
    RenderEditable? found;
    root.visitChildren((child) {
      if (child is RenderEditable) {
        found ??= child;
      } else {
        found ??= _findRenderEditable(child);
      }
    });
    return found;
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

    // A thumb with `thumbVisibility: true` paints even when there is nothing to
    // scroll, so the thumb is only asked for when the code area actually has
    // horizontal reach: a full-width bar on a short file is a lie about what it
    // can do, and it squats on the bottom edge of every narrow document.
    //
    // The bar itself is never mounted conditionally. Inserting a widget above
    // the scroll view rebuilds the `SingleChildScrollView` at a different depth,
    // which unmounts its `Scrollable` and takes the scroll offset with it — that
    // reset lands on the caret reveal that Flutter's `EditableText` schedules
    // while typing, and the code jumps back to the left edge after every width
    // change. A stable tree with a hidden thumb has no such fault.
    //
    // The reach is measured rather than asked of the scroll position, and the
    // measurement is the one the IntrinsicWidth column below already performs —
    // its width is `Text(longestLine)` plus the 16px padding the trick adds,
    // clamped from below by the viewport width — so the two cannot disagree.
    // Listening for the answer would not help: a controller announces offset
    // changes, and a ScrollMetricsNotification forces this field through a
    // second build pass, which per-line background builders are sensitive to.
    final linePainter = TextPainter(
      text: TextSpan(text: longestLine, style: textStyle),
      textDirection: _textDirection,
    )..layout();
    final contentWidth = linePainter.width + 16;
    linePainter.dispose();

    return Scrollbar(
      controller: _horizontalCodeScroll,
      thumbVisibility: contentWidth > minWidth - widget.padding.right,
      // Interactive regardless of platform: on the touch platforms Flutter
      // defaults `interactive` to false, which would leave the thumb a
      // decoration that cannot be dragged. With no thumb painted the
      // recognizers find no thumb to grab, so a hidden bar stays inert.
      interactive: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(right: widget.padding.right),
        scrollDirection: Axis.horizontal,
        controller: _horizontalCodeScroll,
        child: intrinsic,
      ),
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

    // Resolved after the nulling above on purpose: `_backgroundCol` is
    // non-null until then, so resolving earlier would strand the popup on
    // `DefaultStyles.backgroundColor` and never reach the card colour.
    _popupBackground =
        widget.autocompleteBackground ?? _backgroundCol ?? themeData.cardColor;

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

    _textDirection = widget.textDirection ?? Directionality.of(context);

    final codeField = TextField(
      focusNode: _focusNode,
      scrollPadding: widget.padding,
      style: textStyle,
      textDirection: _textDirection,
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
        contentPadding: EdgeInsets.symmetric(
          vertical: codeFieldVerticalPadding,
        ),
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      cursorColor: widget.cursorColor ?? defaultTextStyle.color,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      readOnly: widget.readOnly,
      // Never forward a *null* builder here. `TextField` gives
      // `contextMenuBuilder` the private `_defaultContextMenuBuilder`, and
      // that default is only reachable by leaving the argument out: an
      // explicit null disables the selection toolbar outright, so Copy /
      // Select All silently disappear from every `CodeField`. Falling back to
      // the same widget `TextField` would have built keeps the platform menu.
      contextMenuBuilder:
          widget.contextMenuBuilder ?? _defaultContextMenuBuilder,
    );

    final editingText = LayoutBuilder(
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
    );

    final editingField = Theme(
      data: Theme.of(
        context,
      ).copyWith(textSelectionTheme: widget.textSelectionTheme),
      // The tint layer is only in the tree when a host asked for one, so a
      // field with neither lineBackgroundBuilder nor currentLineColor keeps its
      // exact widget tree.
      child:
          widget.controller.lineBackgroundBuilder == null &&
              widget.controller.currentLineColor == null
          ? editingText
          : Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _backgroundScroll,
                    child: LineBackgroundLayer(
                      controller: widget.controller,
                      rowHeights: _visibleRowHeights(textStyle),
                    ),
                  ),
                ),
                editingText,
              ],
            ),
    );

    final actions = <Type, Action<Intent>>{
      ...widget.controller.actions,
      // Scrolling is a view concern, so this one is wired by the state —
      // the action needs the field's own scroll controller, which lives
      // here rather than on the controller.
      PageScrollIntent: PageScrollAction(scrollController: _codeScroll),
    };

    return FocusableActionDetector(
      actions: actions,
      shortcuts: shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: _backgroundCol,
        key: _codeFieldKey,
        padding: const EdgeInsets.only(left: 8),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The gutter and the code area share the row, and each needs
                // the other to keep its width: the code area is `Expanded`, so
                // it takes exactly the width the gutter leaves. The gutter is
                // therefore bounded rather than given a flex share — a flex
                // allocation is never handed back when a child takes less than
                // it, so `Flexible` here would shrink the code area by the
                // gutter's slack at every field width.
                //
                // Unbounded, a `Row` lays a non-flex child out at its own
                // requested size, so a field narrower than the gutter got a
                // gutter wider than the field: `A RenderFlex overflowed by N
                // pixels`, numbers painted past the widget's edge, and a
                // `TextField` laid out out of sight beside them (#259). The
                // gutter is the party that gives way, because it is the one
                // whose advertised width is a preference. An unbounded row —
                // the field inside a scroll view — bounds nothing.
                if (widget.gutterStyle.showGutter)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: _buildGutter(),
                  ),
                Expanded(key: _editorKey, child: editingField),
              ],
            );
          },
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
  /// The result is memoised on (controller text, width) — see
  /// [_rowHeightsForText] — because this runs from `build()` and re-measuring
  /// every line of the file on every rebuild is the wrap path's dominant cost.
  List<double>? _wrappedRowHeights(TextStyle codeTextStyle) {
    final textWidth = _editorTextWidth;
    if (!widget.wrap || textWidth == null) {
      return null;
    }

    final text = widget.controller.text;
    if (_rowHeightsForText == text && _rowHeightsForWidth == textWidth) {
      return _cachedRowHeights;
    }

    final rows = _measureWrappedRows(codeTextStyle, textWidth);
    final code = _codePosition;
    if (code == null || !code.hasContentDimensions) {
      // The editor has no measurable extent yet (mid-frame, or its very first
      // layout): return the plain measurement but leave the cache unset, so
      // the calibration still gets its chance on the following build rather
      // than being frozen out of the first frame's result.
      return rows;
    }

    var best = rows;
    final excess = _gutterRowExcess(rows);

    if (excess.abs() >= 0.5) {
      // The editor reserves a few logical pixels of its own insets that the
      // `LayoutBuilder` width knows nothing about, so the measured rows can
      // fall either side of the field's real wrapping and the two scroll views
      // disagree about how long the content is. Search the adjacent widths —
      // the gutter is fixed width, so this never feeds back into the layout —
      // and keep the set of rows that makes the heights agree again.
      //
      // LIMITATION: the objective is the *sum* of the measured rows against
      // the editor's own extent, not each line's start. Two lines that err in
      // opposite directions cancel in that sum, so the search can settle on a
      // width whose totals match while individual numbers are still off by a
      // row. Comparing per-line would need the editor's own caret origins,
      // which only its `RenderEditable` exposes and which lag a frame behind
      // this build-time measurement, so the sum is what the width search has;
      // `wrap_true_test.dart`'s per-line alignment test pins the property the
      // gutter actually relies on.
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
    }

    _rowHeightsForText = text;
    _rowHeightsForWidth = textWidth;
    return _cachedRowHeights = best;
  }

  /// Height of each visible line's row for the per-line background layer.
  ///
  /// What the gutter is told: the wrapped rows when the editor wraps, one line
  /// high for every row when it does not. The layer then lands a tint on the
  /// same row the gutter labels with the same line number.
  List<double> _visibleRowHeights(TextStyle codeTextStyle) {
    final wrapped = _wrappedRowHeights(codeTextStyle);
    if (wrapped != null) {
      return wrapped;
    }

    final visibleLineCount =
        widget.controller.code.hiddenLineRanges.visibleLineNumbers.length;

    return List<double>.filled(
      visibleLineCount,
      _singleLineHeight(codeTextStyle),
    );
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
  /// Both scroll views carry `_contentInsets` of vertical padding (the
  /// editor's `contentPadding`, the gutter's outer `Padding`) read from
  /// [codeFieldVerticalPadding], so those cancel and only the rows are left to
  /// disagree.
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
    // Skip the whole-text TextPainter relayout when neither the text nor the
    // selection moved — e.g. an analysis result or search result notification.
    // Those carry the same caret and document, so recomputing the popup offset
    // is pure waste on large documents.
    final value = widget.controller.value;
    if (value.text == _lastPopupText &&
        value.selection == _lastPopupSelection &&
        _textDirection == _lastPopupDirection) {
      return;
    }
    _lastPopupText = value.text;
    _lastPopupSelection = value.selection;
    _lastPopupDirection = _textDirection;

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

  /// The whole text laid out the way the field lays it out.
  ///
  /// With `wrap` set the editor reflows its text to the field's width, so the
  /// caret offsets this painter feeds to the autocomplete popup must come from
  /// a *bounded* layout too: unbounded, a long wrapped line's caret sits
  /// several visual rows away from where the field actually draws it.
  ///
  /// The direction is the one the field is rendering in. An RTL caret is a
  /// horizontal offset from the *right* edge, so measuring it as
  /// [TextDirection.ltr] would put the popup on the wrong side of the editor.
  ///
  /// Known limitation, kept from the LTR-only days: [_getPopupLeftOffset]
  /// converts the caret to a viewport x with
  /// `caret.dx + padding.left − horizontalScroll`, which assumes the
  /// paragraph's left edge sits at the viewport's left edge. That holds while
  /// the line fits — the case the popup targets. Once an RTL line overflows
  /// and the field scrolls horizontally, the line anchors at its *right* edge
  /// instead, and the scrolled popup x drifts. Fixing that needs RTL scroll
  /// semantics in the conversion; until then the unscrolled path above is the
  /// only one this painter guarantees.
  TextPainter _getTextPainter(String text) {
    final painter = TextPainter(
      textDirection: _textDirection,
      text: TextSpan(text: text, style: textStyle),
    );
    final maxWidth = _editorTextWidth;
    if (widget.wrap && maxWidth != null && maxWidth > 0) {
      painter.layout(maxWidth: maxWidth);
    } else {
      painter.layout();
    }
    return painter;
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
          backgroundColor: _popupBackground,
          parentFocusNode: _focusNode!,
          suggestionItemBuilder: widget.suggestionItemBuilder,
        );
      },
    );
  }
}
