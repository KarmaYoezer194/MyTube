import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the dark and light [ThemeData] for the whole app.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brandRed,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.brandRed,
          onPrimary: Colors.white,
          surface: c.background,
          onSurface: c.textPrimary,
          onSurfaceVariant: c.textSecondary,
          outlineVariant: c.divider,
        );

    final baseText = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      extensions: [c],
      // Phones have no mouse: no grey "hover" shading when the pointer is
      // over a card or button in Chrome. (Tap ripples still work.)
      hoverColor: Colors.transparent,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(hoverColor: Colors.transparent),
      ),
      textTheme: baseText.apply(
        fontFamily: 'Roboto',
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      iconTheme: IconThemeData(color: c.textPrimary, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textPrimary,
        textColor: c.textPrimary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheetBackground,
        modalBackgroundColor: c.sheetBackground,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.textSecondary,
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.sheetBackground,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF323232),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: Color(0xFF3EA6FF),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandRed,
      ),
      // Pill-shaped buttons everywhere (like YouTube).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.chipSelectedBackground,
          foregroundColor: c.chipSelectedForeground,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brightness == Brightness.dark
              ? const Color(0xFF3EA6FF)
              : const Color(0xFF065FD4),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
