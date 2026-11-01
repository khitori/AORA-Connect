// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

abstract final class AppColors {
  static Color hsl(
    double hue,
    double saturation,
    double lightness, {
    double alpha = 1,
  }) => HSLColor.fromAHSL(
    alpha,
    hue,
    saturation / 100,
    lightness / 100,
  ).toColor();

  static Color get paper => hsl(60, 8.3, 95.3);
  static Color get paperDark => hsl(60, 4.2, 94.6);
  static Color get card => hsl(0, 0, 100);
  static Color get glass => hsl(0, 0, 100, alpha: 0.84);
  static Color get ink => hsl(240, 8, 9.8);

  static Color get muted700 => hsl(240, 4.8, 28.4);
  static Color get muted600 => hsl(240, 4, 34.7);
  static Color get muted500 => hsl(240, 3.7, 37.5);
  static Color get muted400 => hsl(240, 3.2, 42.9);
  static Color get muted300 => hsl(240, 2.5, 61.4);

  static Color get lineStrong => hsl(60, 5.4, 85.5);
  static Color get line => hsl(60, 5.1, 88.4);
  static Color get divider => hsl(60, 4.7, 83.1);
  static Color get accent => hsl(2.7, 78.5, 49.2);
  static Color get accentDark => hsl(2.6, 80.4, 40);
  // Icons of actions that are currently working (refreshing, checking).
  static const active = Color.fromARGB(255, 255, 56, 60);
  static Color get protocolHysteria2 => hsl(268, 54, 43);
  static Color get protocolVless => hsl(213, 69, 40);
  static Color get protocolTrojan => hsl(27, 76, 39);
  static Color get protocolShadowsocks => hsl(169, 65, 32);
  static Color get protocolVmess => hsl(288, 49, 39);
  static Color get islandShadow => ink.withValues(alpha: 0.06);

  // Glass surface for clickable foreground elements (see GlassSurface).
  static const glassTop = Color(0xFFE6E6E6);
  static const glassBottom = Color(0xFFFFFFFF);
  static Color get glassEdge => card.withValues(alpha: 0.75);
  static const glassShadow = Color(0x1A000000); // black, 10%
  // Off-state toggle track: a groove, darker at the top.
  static const toggleGrooveTop = Color(0xFFDADADA);
  static const toggleGrooveBottom = Color(0xFFEDEDED);
  // Opened dropdown menus: translucent white over a backdrop blur.
  static Color get menuGlass => card.withValues(alpha: 0.35);
}
