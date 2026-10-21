import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'actions/comment_uncomment.dart';
import 'actions/enter_key.dart';
import 'actions/indent.dart';
import 'actions/outdent.dart';
import 'actions/overtype.dart';
import 'actions/page_scroll.dart';
import 'actions/search.dart';
import 'actions/tab.dart';

/// The shortcuts the code field binds.
///
/// The table is shared by both renderers: the text field renderer wires it
/// into a `FocusableActionDetector`, the re_editor renderer into a `Shortcuts`
/// widget around the editor. re_editor binds some of the same keys itself —
/// Tab, Enter, the undo keys — and its own binding wins, because its
/// `Shortcuts` widget sits closer to the focus node. The re_editor renderer
/// therefore overrides the *actions* of the intents re_editor raises, so the
/// package's own editing semantics win even where the key binding does not.
final codeFieldShortcuts = <ShortcutActivator, Intent>{
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
final codeFieldShortcutsIgnoringComposition = <ShortcutActivator, Intent>{
  // Dismiss
  LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),

  // EnterKey
  LogicalKeySet(LogicalKeyboardKey.enter): const EnterKeyIntent(),

  // TabKey
  LogicalKeySet(LogicalKeyboardKey.tab): const TabKeyIntent(),

  // Overtype: bare Insert. Flutter has no overtype hook
  // (flutter/flutter#122673) and `DefaultTextEditingShortcuts` binds only
  // Ctrl-Insert (copy) and Shift-Insert (paste), so the bare key reaches here.
  // A SingleActivator with no modifiers does not match a modified Insert, so the
  // copy binding above keeps working. Ignored while composing for the same
  // reason as Enter and Tab: the keystroke belongs to the IME.
  const SingleActivator(LogicalKeyboardKey.insert):
      const ToggleOvertypeIntent(),
};
