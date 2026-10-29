import 'package:flutter/material.dart';

/// All the colors of the app in one place.
///
/// Colors that change between dark and light theme live inside an
/// [AppColors] object (one for dark, one for light). Flutter stores it in
/// the theme, so any widget can read it with `context.colors`.
///
/// Colors that never change (brand red, duration badge) are `static const`.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.chipSelectedBackground,
    required this.chipSelectedForeground,
    required this.sheetBackground,
  });

  /// Page background.
  final Color background;

  /// Chips, pills, cards and other raised things.
  final Color surface;

  /// Titles and normal text.
  final Color textPrimary;

  /// Meta text such as "Channel · 1.2M views · 3 days ago".
  final Color textSecondary;

  /// Thin lines between sections.
  final Color divider;

  /// Selected category chip and the Subscribe pill.
  final Color chipSelectedBackground;
  final Color chipSelectedForeground;

  /// Background of bottom sheets (a little lighter than the page in dark mode).
  final Color sheetBackground;

  // ---- Colors that are the same in both themes ----

  /// Brand red: logo, progress bar, scrubber dot, badges.
  static const Color brandRed = Color(0xFFFF0000);

  /// Duration badge on thumbnails: black at 80% opacity (0xCC = 80%).
  static const Color durationBadge = Color(0xCC000000);

  /// The area on both sides of the 430px phone column on wide screens.
  static const Color outsideFrame = Color(0xFF000000);

  /// Grey used behind thumbnails while they load, and for skeletons.
  static const Color placeholderDark = Color(0xFF3A3A3A);
  static const Color placeholderLight = Color(0xFFE5E5E5);

  static const AppColors dark = AppColors(
    background: Color(0xFF0F0F0F),
    surface: Color(0xFF272727),
    textPrimary: Color(0xFFF1F1F1),
    textSecondary: Color(0xFFAAAAAA),
    divider: Color(0xFF3F3F3F),
    chipSelectedBackground: Color(0xFFFFFFFF),
    chipSelectedForeground: Color(0xFF0F0F0F),
    sheetBackground: Color(0xFF212121),
  );

  static const AppColors light = AppColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF2F2F2),
    textPrimary: Color(0xFF0F0F0F),
    textSecondary: Color(0xFF606060),
    divider: Color(0xFFE5E5E5),
    chipSelectedBackground: Color(0xFF0F0F0F),
    chipSelectedForeground: Color(0xFFFFFFFF),
    sheetBackground: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? chipSelectedBackground,
    Color? chipSelectedForeground,
    Color? sheetBackground,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      chipSelectedBackground:
          chipSelectedBackground ?? this.chipSelectedBackground,
      chipSelectedForeground:
          chipSelectedForeground ?? this.chipSelectedForeground,
      sheetBackground: sheetBackground ?? this.sheetBackground,
    );
  }

  /// Used by Flutter to animate smoothly when the theme switches.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      chipSelectedBackground: Color.lerp(
        chipSelectedBackground,
        other.chipSelectedBackground,
        t,
      )!,
      chipSelectedForeground: Color.lerp(
        chipSelectedForeground,
        other.chipSelectedForeground,
        t,
      )!,
      sheetBackground: Color.lerp(sheetBackground, other.sheetBackground, t)!,
    );
  }
}

/// Lets you write `context.colors.textSecondary` anywhere in the app.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
