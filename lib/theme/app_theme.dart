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

  /// A hover and press tint for one element, from its own two colors.
  static WidgetStateProperty<Color?> overlay(Color hover, Color pressed) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return pressed;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return hover;
        }
        return null;
      });

  static WidgetStateProperty<Color?> get controlOverlayColor =>
      overlay(AppColors.defaultHover, AppColors.defaultPressed);

  /// The theme of the active palette ([AppColors.current]): light or dark.
  static ThemeData get current {
    final accentSurface = Color.alphaBlend(
      AppColors.defaultAccent.withValues(alpha: 0.08),
      AppColors.defaultSurface,
    );
    final colors = (AppColors.isDark ? ColorScheme.dark : ColorScheme.light)(
      primary: AppColors.defaultAccent,
      onPrimary: AppColors.defaultOnAccent,
      primaryContainer: accentSurface,
      onPrimaryContainer: AppColors.errorText,
      secondary: AppColors.defaultSecondary,
      onSecondary: AppColors.defaultSurface,
      secondaryContainer: AppColors.defaultSurface,
      onSecondaryContainer: AppColors.defaultText,
      tertiary: AppColors.defaultText,
      onTertiary: AppColors.defaultSurface,
      tertiaryContainer: AppColors.defaultSurfaceDim,
      onTertiaryContainer: AppColors.defaultText,
      error: AppColors.errorText,
      onError: AppColors.defaultOnAccent,
      errorContainer: accentSurface,
      onErrorContainer: AppColors.errorText,
      surface: AppColors.pageBackground,
      onSurface: AppColors.defaultText,
      onSurfaceVariant: AppColors.defaultTextSecondary,
      surfaceDim: AppColors.defaultSurfaceDim,
      surfaceBright: AppColors.defaultSurface,
      surfaceContainerLowest: AppColors.defaultSurface,
      surfaceContainerLow: AppColors.defaultSurfaceDim,
      surfaceContainer: AppColors.defaultSurface,
      surfaceContainerHigh: AppColors.defaultSurfaceDim,
      surfaceContainerHighest: AppColors.defaultBorderFaint,
      outline: AppColors.defaultBorder,
      outlineVariant: AppColors.defaultBorderFaint,
      inverseSurface: AppColors.defaultText,
      onInverseSurface: AppColors.pageBackground,
      inversePrimary: AppColors.defaultAccent,
      shadow: AppColors.defaultShadow,
      scrim: AppColors.defaultText,
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
      scaffoldBackgroundColor: AppColors.pageBackground,
      disabledColor: AppColors.defaultDisabled,
      dividerColor: AppColors.defaultDivider,
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.pageBackground,
        foregroundColor: AppColors.defaultText,
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
          foregroundColor: AppColors.buttonText,
          // The selection style, like outlined dropdowns: white with the white
          // glass edge and no grey outline. Island-style buttons use
          // IslandButton or RoundIconButton instead.
          backgroundColor: AppColors.buttonBackground,
          side: BorderSide.none,
          shape: GlassBorder(
            radius: controlRadius,
            innerBorder: AppColors.buttonInnerBorder,
          ),
        ).copyWith(overlayColor: controlOverlayColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: AppColors.defaultAccent,
          foregroundColor: AppColors.defaultOnAccent,
          disabledBackgroundColor: AppColors.defaultSurfaceDim,
          disabledForegroundColor: AppColors.defaultDisabled,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.defaultAccent,
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
        fillColor: AppColors.defaultSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: TextStyle(color: AppColors.defaultTextSecondary),
        floatingLabelStyle: TextStyle(color: AppColors.defaultAccent),
        hintStyle: TextStyle(color: AppColors.defaultDisabled),
        border: inputBorder(AppColors.defaultBorder),
        enabledBorder: inputBorder(AppColors.defaultBorder),
        disabledBorder: inputBorder(AppColors.defaultBorderFaint),
        focusedBorder: inputBorder(AppColors.defaultAccent, width: 2),
        errorBorder: inputBorder(AppColors.errorText),
        focusedErrorBorder: inputBorder(AppColors.errorText, width: 2),
      ),
      // No dimming behind dialogs: the glass dialog stands out on its own.
      dialogTheme: const DialogThemeData(barrierColor: Colors.transparent),
      dividerTheme: DividerThemeData(
        color: AppColors.defaultDivider,
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: AppColors.defaultText),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.defaultAccent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.defaultSurface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.defaultText,
        contentTextStyle: TextStyle(color: AppColors.defaultSurface),
        actionTextColor: AppColors.defaultSurface,
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
                ? AppColors.buttonIconDisabled
                : AppColors.buttonIcon,
          ),
        ),
      ),
    );
  }
}
