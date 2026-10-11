import 'package:flutter/material.dart';

import '../analyzer/models/issue_type.dart';

/// The glyph the gutter shows for an issue when the style overrides nothing.
///
/// Every [IssueType] falls back to it — the one icon the gutter has always
/// rendered — so a style that sets none of the icon fields looks exactly as it
/// did before they existed.
const IconData defaultIssueIcon = Icons.cancel;

class GutterStyle {
  /// Width of the line number column.
  final double width;

  /// Alignment of the numbers in the column.
  final TextAlign textAlign;

  /// Style of the numbers.
  ///
  /// [TextStyle.fontSize] and [TextStyle.fontFamily] are ignored
  /// and taken from the widget style or [TextTheme.titleMedium] for consistency
  /// with lines. Everything else applies.
  ///
  /// Of omitted, the widget or theme value is used with the color of
  /// half the opacity.
  final TextStyle? textStyle;

  /// Style of the error popup.
  final TextStyle? errorPopupTextStyle;

  /// Glyph the gutter shows for an [IssueType.error] issue.
  ///
  /// Null renders [defaultIssueIcon], which is what every issue type has
  /// always shown. Only the glyph is overridable: the icon is rendered 16px in
  /// the 16-wide issue column, so its size is part of the row geometry and
  /// comes from the gutter, not from the style.
  final IconData? errorIcon;

  /// Glyph the gutter shows for an [IssueType.warning] issue.
  ///
  /// Null renders [defaultIssueIcon], so setting nothing here leaves warnings
  /// looking exactly as they did.
  final IconData? warningIcon;

  /// Glyph the gutter shows for an [IssueType.info] issue.
  ///
  /// Null renders [defaultIssueIcon], so setting nothing here leaves info
  /// looking exactly as it did.
  final IconData? infoIcon;

  /// Decoration of the error popup's container.
  ///
  /// Null derives it from [errorPopupTextStyle]'s `backgroundColor` and
  /// `color`, which is what the popup has always done.
  final BoxDecoration? errorPopupDecoration;

  /// Background of the line number column.
  final Color? background;

  /// Central horizontal margin between the numbers and the code.
  final double margin;

  /// Extra padding around the whole gutter column, applied outside the
  /// number/error/folding columns.
  ///
  /// Defaults to [EdgeInsets.zero], which renders exactly like no
  /// padding at all.
  final EdgeInsets padding;

  /// Whether to show line numbers column.
  final bool showLineNumbers;

  /// Whether to show errors column.
  final bool showErrors;

  /// Whether to show folding handles column.
  final bool showFoldingHandles;

  /// Whether there is any column to show in gutter.
  bool get showGutter => showLineNumbers || showErrors || showFoldingHandles;

  /// The glyph to render for an issue of [type].
  ///
  /// The matching field when the style supplies one, [defaultIssueIcon]
  /// otherwise. Never null, so a caller never has to re-apply the fallback.
  IconData issueIcon(IssueType type) => switch (type) {
    IssueType.error => errorIcon ?? defaultIssueIcon,
    IssueType.warning => warningIcon ?? defaultIssueIcon,
    IssueType.info => infoIcon ?? defaultIssueIcon,
  };

  const GutterStyle({
    this.margin = 10.0,
    this.padding = EdgeInsets.zero,
    this.textAlign = TextAlign.right,
    this.showErrors = true,
    this.showFoldingHandles = true,
    this.showLineNumbers = true,
    this.width = 80.0,
    this.background,
    this.errorPopupTextStyle,
    this.errorIcon,
    this.warningIcon,
    this.infoIcon,
    this.errorPopupDecoration,
    this.textStyle,
  });

  /// Hides the gutter entirely.
  ///
  /// Use this instead of all-`false` because new elements can be added
  /// to the gutter in the future versions.
  static const GutterStyle none = GutterStyle(
    showErrors: false,
    showFoldingHandles: false,
    showLineNumbers: false,
  );

  GutterStyle copyWith({
    TextStyle? errorPopupTextStyle,
    TextStyle? textStyle,
    EdgeInsets? padding,
    IconData? errorIcon,
    IconData? warningIcon,
    IconData? infoIcon,
    BoxDecoration? errorPopupDecoration,
  }) => GutterStyle(
    width: width,
    textAlign: textAlign,
    textStyle: textStyle ?? this.textStyle,
    errorPopupTextStyle: errorPopupTextStyle ?? this.errorPopupTextStyle,
    errorIcon: errorIcon ?? this.errorIcon,
    warningIcon: warningIcon ?? this.warningIcon,
    infoIcon: infoIcon ?? this.infoIcon,
    errorPopupDecoration: errorPopupDecoration ?? this.errorPopupDecoration,
    background: background,
    margin: margin,
    padding: padding ?? this.padding,
    showErrors: showErrors,
    showFoldingHandles: showFoldingHandles,
    showLineNumbers: showLineNumbers,
  );
}

@Deprecated('Renamed to GutterStyle')
typedef LineNumberStyle = GutterStyle;
