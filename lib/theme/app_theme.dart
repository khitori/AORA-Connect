// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Global widget defaults. Individual components can override these styles.
abstract final class AppTheme {
  static const controlRadius = 12.0;
  static const controlHeight = 36.0;

  static Color get selectedSurface => AppColors.ink.withValues(alpha: 0.06);

  static WidgetStateProperty<Color?> get controlOverlayColor =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppColors.ink.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return AppColors.ink.withValues(alpha: 0.06);
        }
        return null;
      });

  static ThemeData get light {
    final accentSurface = Color.alphaBlend(
      AppColors.accent.withValues(alpha: 0.08),
      AppColors.card,
    );
    final colors = ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.card,
      primaryContainer: accentSurface,
      onPrimaryContainer: AppColors.accentDark,
      secondary: AppColors.muted700,
      onSecondary: AppColors.card,
      secondaryContainer: AppColors.card,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.ink,
      onTertiary: AppColors.card,
      tertiaryContainer: AppColors.paperDark,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.accentDark,
      onError: AppColors.card,
      errorContainer: accentSurface,
      onErrorContainer: AppColors.accentDark,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted400,
      surfaceDim: AppColors.paperDark,
      surfaceBright: AppColors.card,
      surfaceContainerLowest: AppColors.card,
      surfaceContainerLow: AppColors.paperDark,
      surfaceContainer: AppColors.card,
      surfaceContainerHigh: AppColors.paperDark,
      surfaceContainerHighest: AppColors.line,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
      inversePrimary: AppColors.accent,
      shadow: AppColors.islandShadow,
      scrim: AppColors.ink,
      surfaceTint: Colors.transparent,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    OutlineInputBorder inputBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.paper,
      disabledColor: AppColors.muted300,
      dividerColor: AppColors.divider,
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: BorderSide(color: AppColors.lineStrong),
          shape: shape,
        ).copyWith(overlayColor: controlOverlayColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.card,
          disabledBackgroundColor: AppColors.paperDark,
          disabledForegroundColor: AppColors.muted300,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          shape: shape,
        ).copyWith(overlayColor: controlOverlayColor),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(overlayColor: controlOverlayColor),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        labelStyle: TextStyle(color: AppColors.muted400),
        floatingLabelStyle: TextStyle(color: AppColors.accent),
        hintStyle: TextStyle(color: AppColors.muted300),
        border: inputBorder(AppColors.lineStrong),
        enabledBorder: inputBorder(AppColors.lineStrong),
        disabledBorder: inputBorder(AppColors.line),
        focusedBorder: inputBorder(AppColors.accent, width: 2),
        errorBorder: inputBorder(AppColors.accentDark),
        focusedErrorBorder: inputBorder(AppColors.accentDark, width: 2),
      ),
      dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1),
      iconTheme: IconThemeData(color: AppColors.ink),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: AppColors.card),
        actionTextColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
    );
  }
}
