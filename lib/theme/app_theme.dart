// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'glass_surface.dart';

abstract final class AppTheme {
  static const controlRadius = 12.0;
  static const controlHeight = 36.0;

  /// The section rule: the space between elements in a section, the same as
  /// above and below the header icon (8 padding plus (64 - 40) / 2). A
  /// subsection name keeps [sectionLabelGap] to its control, and buttons in a
  /// group keep [sectionButtonGap] between them.
  static const sectionGap = 20.0;
  static const sectionLabelGap = 12.0;
  static const sectionButtonGap = 12.0;

  /// Corner radius of section cards and dialogs.
  static const sectionRadius = 38.0;

  /// Space after a section's separator and below its content.
  static const sectionContentTopPadding = sectionGap;

  /// The main side padding inside white boxes: the main page's subscription
  /// and server box with its dropdown, and the Subscriptions page boxes and
  /// server rows. Section cards use [sectionPadding] instead.
  static const contentPadding = 20.0;

  /// Side padding in section cards (Settings, Routing). The hoverable rows
  /// (selects, toggle rows) are padded by it, the rest of the content is inset
  /// by it, and those rows reach back out by it ([SectionRowBleed]), so all
  /// text lines up.
  static const sectionPadding = 16.0;

  /// Corner radius of taller hoverable rows in a section (toggle rows) and of
  /// a plain select's open menu. Half the 48px height of a plain select, so
  /// their corners curve the same as that select's pill ends.
  static const sectionRowRadius = 24.0;

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
    final theme = ThemeData(
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
          minimumSize: const Size(64, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.ink,
          // The selection style, like outlined dropdowns: white with the white
          // glass edge and no grey outline. Island-style buttons use
          // IslandButton or RoundIconButton instead.
          backgroundColor: AppColors.card,
          side: BorderSide.none,
          shape: const GlassBorder(radius: controlRadius),
        ).copyWith(overlayColor: controlOverlayColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.card,
          disabledBackgroundColor: AppColors.paperDark,
          disabledForegroundColor: AppColors.muted300,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.accent,
          shape: shape,
        ).copyWith(overlayColor: controlOverlayColor),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(overlayColor: controlOverlayColor),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        visualDensity: VisualDensity.standard,
        isDense: true,
        constraints: const BoxConstraints(minHeight: controlHeight),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      // No dimming behind dialogs: the glass dialog stands out on its own.
      dialogTheme: const DialogThemeData(barrierColor: Colors.transparent),
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
    // Outlined buttons share the selection fields' text and grey icons, so a
    // button like "Add rule" reads the same as a dropdown next to it.
    return theme.copyWith(
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: theme.outlinedButtonTheme.style!.copyWith(
          // The type scale's sizes are not part of theme.textTheme yet while
          // the theme is built, so take titleMedium from the scale itself.
          textStyle: WidgetStatePropertyAll(
            Typography.material2021().englishLike.titleMedium,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.muted300
                : AppColors.muted500,
          ),
        ),
      ),
    );
  }
}
