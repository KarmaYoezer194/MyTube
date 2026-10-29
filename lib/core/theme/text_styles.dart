import 'package:flutter/material.dart';

/// Text sizes used across the app.
///
/// These styles have no color on purpose: the color comes from the theme
/// (`context.colors`), so the same style works in dark and light mode.
/// Example: `AppTextStyles.meta.copyWith(color: context.colors.textSecondary)`
class AppTextStyles {
  AppTextStyles._();

  /// Video title on the home feed and watch page.
  static const TextStyle videoTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Bigger title on the watch page.
  static const TextStyle watchTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// "Channel · 1.2M views · 3 days ago"
  static const TextStyle meta = TextStyle(
    fontSize: 12,
    height: 1.35,
  );

  /// Section headers like "History" or "Shorts".
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  /// Normal body text (descriptions, comments).
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.4,
  );

  /// Text inside chips and pill buttons.
  static const TextStyle chip = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Labels under the bottom navigation icons.
  static const TextStyle navLabel = TextStyle(
    fontSize: 10,
    height: 1.2,
  );

  /// Text inside the duration badge on thumbnails.
  static const TextStyle durationBadge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
}
