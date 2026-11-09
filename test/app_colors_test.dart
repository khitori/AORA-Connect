// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/theme/app_colors.dart';
import 'package:aoravpn/theme/app_theme.dart';

void main() {
  tearDown(() => AppColors.current = AppColors.light);

  test('Basic colors and the theme follow the active palette', () {
    AppColors.current = AppColors.light;
    expect(AppColors.isDark, isFalse);
    expect(AppColors.pageBackground, AppColors.light.pageBackground);
    expect(AppTheme.current.brightness, Brightness.light);
    expect(
      AppTheme.current.scaffoldBackgroundColor,
      AppColors.light.pageBackground,
    );

    AppColors.current = AppColors.dark;
    expect(AppColors.isDark, isTrue);
    expect(AppColors.pageBackground, AppColors.dark.pageBackground);
    expect(AppColors.defaultText, AppColors.dark.defaultText);
    expect(AppTheme.current.brightness, Brightness.dark);
    expect(
      AppTheme.current.scaffoldBackgroundColor,
      AppColors.dark.pageBackground,
    );
  });

  test('Reloading the palettes keeps the active theme', () {
    final oldDark = AppColors.dark;
    AppColors.current = oldDark;

    AppColors.reloadPalettes();

    expect(AppColors.dark, isNot(same(oldDark)));
    expect(AppColors.current, same(AppColors.dark));

    AppColors.current = AppColors.light;
    AppColors.reloadPalettes();
    expect(AppColors.current, same(AppColors.light));
  });
}
