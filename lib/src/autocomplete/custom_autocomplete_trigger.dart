import 'dart:async';

/// One custom autocomplete trigger.
///
/// `CodeController` asks a registered trigger for suggestions as soon as its
/// [trigger] appears in the text before the caret, and passes the text typed
/// after it. This is the seam upstream
/// `akvelon/flutter-code-editor#220` asked for: a host that wants completion
/// after ` >> ` registers a trigger for ` >> ` and owns the list, instead of
/// subclassing `CodeController` to override `generateSuggestions`.
///
/// ```dart
/// controller.customAutocompleteTriggers = [
///   CustomAutocompleteTrigger(
///     trigger: ' >> ',
///     getSuggestions: (prefix) => keywords.where((k) => k.startsWith(prefix)),
///   ),
/// ];
/// ```
class CustomAutocompleteTrigger {
  CustomAutocompleteTrigger({
    required this.trigger,
    required this.getSuggestions,
  }) : assert(trigger.isNotEmpty, 'trigger must not be empty');

  /// The string that arms this trigger, e.g. `' >> '` or `'@'`.
  ///
  /// Must not be empty: an empty string matches at every caret, which would
  /// take the keyword completer's place everywhere.
  final String trigger;

  /// Called with the text typed after the arming trigger, up to the caret.
  ///
  /// It is called again on every keystroke, so the host narrows its own list by
  /// filtering on the prefix it is handed. Returning an empty list hides the
  /// popup.
  final FutureOr<List<String>> Function(String prefix) getSuggestions;
}
