// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// Every element's colors, per theme. Edit the values in [_lightPalette] and
/// [_darkPalette]; each variable belongs to the one element it is named after.
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

  /// [color] with its opacity scaled by [amount], for things that fade in.
  static Color faded(Color color, double amount) =>
      color.withValues(alpha: color.a * amount);

  static AppPalette light = _lightPalette();
  static AppPalette dark = _darkPalette();

  // ======== LIGHT THEME ========
  static AppPalette _lightPalette() => AppPalette(
    brightness: Brightness.light,

    // Page and plain widgets without their own colors below
    pageBackground: hsl(0, 0, 93),
    defaultSurface: hsl(0, 0, 100),
    defaultSurfaceDim: hsl(60, 4.2, 92.3),
    defaultText: hsl(240, 8, 9.8),
    defaultTextSecondary: hsl(240, 3.2, 42.9),
    defaultSecondary: hsl(240, 4.8, 28.4),
    defaultDisabled: hsl(240, 2.5, 61.4),
    defaultAccent: hsl(2.7, 78.5, 49.2),
    defaultOnAccent: hsl(0, 0, 100),
    defaultBorder: hsl(60, 5.4, 85.5),
    defaultBorderFaint: hsl(60, 5.1, 88.4),
    defaultDivider: hsl(60, 4.7, 83.1),
    defaultShadow: hsl(240, 8, 9.8, alpha: 0.06),
    defaultHover: hsl(240, 8, 9.8, alpha: 0.06),
    defaultPressed: hsl(240, 8, 9.8, alpha: 0.12),
    errorText: hsl(2.6, 80.4, 40),

    // Buttons
    buttonBackground: hsl(0, 0, 100),
    buttonText: hsl(240, 8, 9.8),
    buttonIcon: hsl(240, 3.7, 37.5),
    buttonIconDisabled: hsl(240, 2.5, 61.4),
    buttonInnerBorder: hsl(0, 0, 100, alpha: 0.75),

    // Connect button
    connectbuttonBackground: hsl(0, 0, 100),
    connectbuttonBackgroundOnCenter: hsl(2.7, 78.5, 49.2),
    connectbuttonBackgroundOnEdge: hsl(2.6, 80.4, 40),
    connectbuttonIcon: hsl(240, 3.7, 37.5),
    connectbuttonIconOn: hsl(0, 0, 100),
    connectbuttonTextBusy: hsl(240, 2.5, 61.4),
    connectbuttonSpinner: hsl(2.7, 78.5, 49.2),
    connectbuttonBorder: hsl(60, 5.4, 85),
    connectbuttonBorderOn: hsl(2.6, 80.4, 40),
    connectbuttonGlowOn: hsl(2.7, 78.5, 49.2, alpha: 0.45),
    connectbuttonInnerShade: hsl(240, 0, 50, alpha: 0),
    connectbuttonInnerShadeOn: hsl(240, 8, 9.8, alpha: 0.1),
    connectbuttonInnerLight: hsl(0, 0, 100, alpha: 0),
    connectbuttonInnerLightOn: hsl(0, 0, 100, alpha: 0.1),

    // Bottom navigation panel
    navpanelBackground: hsl(0, 0, 100, alpha: 0.5),
    navpanelOuterBorder: hsl(60, 5.4, 85.5),
    navpanelInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    navpanelShadow: hsl(240, 8, 9.8, alpha: 0.06),
    navpanelHighlightBackgroundTop: hsl(0, 0, 90.2),
    navpanelHighlightBackgroundBottom: hsl(0, 0, 100),
    navpanelHighlightInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    navpanelHighlightOuterBorder: hsl(60, 5.4, 85.5, alpha: 0.35),
    navpanelHighlightShadow: hsl(0, 0, 0, alpha: 0.1),
    navpanelIcon: hsl(240, 3.7, 37.5),
    navpanelIconSelected: hsl(2.7, 78.5, 49.2),
    navpanelIconGlow: hsl(2.7, 78.5, 49.2, alpha: 0.55),
    navpanelLabel: hsl(240, 3.7, 37.5),
    navpanelLabelSelected: hsl(240, 8, 9.8),
    navpanelItemHover: hsl(240, 8, 30, alpha: 0.05),

    // Round glass icon buttons (top bar, section actions)
    iconbuttonBackgroundTop: hsl(0, 0, 90.2),
    iconbuttonBackgroundBottom: hsl(0, 0, 100),
    iconbuttonInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    iconbuttonOuterBorder: hsl(60, 5.4, 85.5, alpha: 0.35),
    iconbuttonShadow: hsl(0, 0, 0, alpha: 0.1),
    iconbuttonIcon: hsl(240, 4.8, 28.4),
    iconbuttonIconDisabled: hsl(240, 2.5, 61.4),
    iconbuttonIconSelected: hsl(2.7, 78.5, 49.2),
    iconbuttonIconWorking: hsl(358.8, 100, 61),
    iconbuttonHover: hsl(240, 8, 9.8, alpha: 0.06),
    iconbuttonPressed: hsl(240, 8, 9.8, alpha: 0.12),

    // Settings sections
    sectionBackground: hsl(0, 0, 100),
    sectionShadow: hsl(240, 8, 9.8, alpha: 0.06),
    sectionDivider: hsl(60, 5.1, 88.4),
    sectionTitle: hsl(240, 8, 9.8),
    sectionSubtitle: hsl(240, 3.2, 42.9),
    sectionLabel: hsl(0, 0, 60),
    sectionIcon: hsl(240, 3.2, 42.9),
    sectionIconOpen: hsl(2.7, 78.5, 49.2),
    sectionIconGlow: hsl(2.7, 78.5, 49.2, alpha: 0.45),
    sectionArrow: hsl(240, 3.2, 42.9),
    sectionArrowOpen: hsl(2.7, 78.5, 49.2),
    sectioniconboxBackgroundTop: hsl(0, 0, 90.2),
    sectioniconboxBackgroundBottom: hsl(0, 0, 100),
    sectioniconboxInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    sectioniconboxOuterBorder: hsl(60, 5.4, 85.5, alpha: 0.35),
    sectioniconboxShadow: hsl(0, 0, 0, alpha: 0.1),
    settingsrowHover: hsl(240, 8, 9.8, alpha: 0.06),

    // Switches
    toggleTrackBackgroundTop: hsl(0, 0, 85.5),
    toggleTrackBackgroundBottom: hsl(0, 0, 92.9),
    toggleTrackBorder: hsl(60, 5.1, 88.4),
    toggleTrackHover: hsl(240, 8, 9.8, alpha: 0.06),
    toggleTrackPressed: hsl(240, 8, 9.8, alpha: 0.12),
    toggleTrackGlowStrong: hsl(2.7, 78.5, 49.2, alpha: 0.5),
    toggleTrackGlowSoft: hsl(2.7, 78.5, 49.2, alpha: 0.22),
    toggleKnobBackgroundTop: hsl(0, 0, 90.2),
    toggleKnobBackgroundBottom: hsl(0, 0, 100),
    toggleKnobOnBackgroundTop: hsl(2.6, 80.4, 40),
    toggleKnobOnBackgroundBottom: hsl(2.7, 78.5, 49.2),
    toggleKnobInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    toggleKnobShadow: hsl(0, 0, 0, alpha: 0.1),
    toggleKnobGlow: hsl(2.7, 78.5, 49.2, alpha: 0.7),

    // Select field
    selectBackground: hsl(0, 0, 100),
    selectValue: hsl(0, 0, 10),
    selectArrow: hsl(240, 3.7, 37.5),
    selectHover: hsl(240, 8, 9.8, alpha: 0.06),
    selectPressed: hsl(240, 8, 9.8, alpha: 0.12),
    selectInnerBorder: hsl(0, 0, 100, alpha: 0.75),

    // Select dropdown menu
    selectdropdownGlass: hsl(0, 0, 100, alpha: 0.35),
    selectdropdownOuterBorder: hsl(60, 5.1, 88.4),
    selectdropdownInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    selectdropdownSeparator: hsl(60, 5.1, 88.4),
    selectdropdownItemText: hsl(240, 8, 9.8),
    selectdropdownItemSelected: hsl(240, 8, 9.8, alpha: 0.06),
    selectdropdownItemHover: hsl(240, 8, 9.8, alpha: 0.06),
    selectdropdownItemPressed: hsl(240, 8, 9.8, alpha: 0.12),

    // Dialogs
    dialogTitle: hsl(0, 0, 0),
    dialogSubtitle: hsl(0, 0, 0),
    dialogBackground: hsl(0, 0, 100, alpha: 0.5),
    dialogOuterBorder: hsl(60, 5.4, 85.5),
    dialogInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    dialogLabel: hsl(0, 0, 40),
    dialogButtonBackground: hsl(215, 10, 76, alpha: 0.28),
    dialogInputBackground: hsl(215, 10, 76, alpha: 0.28),
    dialogInputHint: hsl(240, 2.5, 61.4),
    dialogSelectBackground: hsl(215, 10, 76, alpha: 0.28),
    dialogConfirmButton: hsl(208, 100, 50),
    dialogConfirmButtonText: hsl(0, 0, 100),
    dialogPasteButtonText: hsl(135, 59, 49),

    // Notifications
    notificationBackground: hsl(0, 0, 100, alpha: 0.5),
    notificationOuterBorder: hsl(60, 5.4, 85.5),
    notificationInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    notificationIcon: hsl(240, 3.7, 37.5),
    notificationText: hsl(240, 8, 9.8),
    notificationCloseIcon: hsl(240, 3.7, 37.5),
    notificationCloseHover: hsl(240, 8, 9.8, alpha: 0.06),
    notificationClosePressed: hsl(240, 8, 9.8, alpha: 0.12),

    // Routing rule actions menu (opens from the settings button on a rule)
    routingactionsmenuBackground: hsl(0, 0, 93, alpha: 0.8),
    routingactionsmenuOuterBorder: hsl(60, 5.4, 85.5),
    routingactionsmenuInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    routingactionsmenuIcon: hsl(240, 3.7, 37.5),
    routingactionsmenuIconDisabled: hsl(60, 5.4, 85.5),
    routingactionsmenuIconHover: hsl(240, 3.7, 37.5, alpha: 0.08),
    routingactionsmenuIconPressed: hsl(240, 3.7, 37.5, alpha: 0.1),

    // Warning notices
    warningBackground: hsl(2.7, 76, 95.9),
    warningIcon: hsl(2.6, 80.4, 40),
    warningText: hsl(2.6, 80.4, 40),

    // Main page server panel
    serverpanelBackground: hsl(0, 0, 100),
    serverpanelStatusText: hsl(240, 3.7, 37.5),
    serverpanelDivider: hsl(60, 5.1, 88.4),
    serverrowFallbackIcon: hsl(240, 2.5, 61.4),
    serverrowDetail: hsl(240, 3.7, 37.5),
    serverrowPing: hsl(240, 3.7, 37.5),

    // Protocol names in server details
    protocolHysteria2: hsl(268, 54, 43),
    protocolVless: hsl(213, 69, 40),
    protocolTrojan: hsl(27, 76, 39),
    protocolShadowsocks: hsl(169, 65, 32),
    protocolVmess: hsl(288, 49, 39),
    protocolUnknown: hsl(240, 3.7, 37.5),

    // Subscriptions page
    addsubscriptionbuttonBackground: hsl(0, 0, 100),
    addsubscriptionbuttonText: hsl(240, 8, 9.8),
    subscriptionrowBackground: hsl(0, 0, 100),
    subscriptionrowCheck: hsl(2.7, 78.5, 49.2),
    subscriptiondescriptionBackground: hsl(0, 0, 100),
    subscriptiondescriptionIcon: hsl(240, 3.7, 37.5),
    subscriptiondescriptionLabel: hsl(240, 3.7, 37.5),
    subscriptiontimingBackground: hsl(0, 0, 100),
    subscriptiontimingIcon: hsl(240, 3.7, 37.5),
    subscriptiontimingLabel: hsl(240, 3.7, 37.5),
    subscriptiontimingDetail: hsl(240, 3.7, 37.5),

    // Routing page
    addrulebuttonBackground: hsl(0, 0, 100),
    routingruleBackground: hsl(0, 0, 100),
    routingruleiconboxBackgroundTop: hsl(0, 0, 90.2),
    routingruleiconboxBackgroundBottom: hsl(0, 0, 100),
    routingruleiconboxInnerBorder: hsl(0, 0, 100, alpha: 0.75),
    routingruleiconboxOuterBorder: hsl(60, 5.4, 85.5, alpha: 0.35),
    routingruleiconboxShadow: hsl(0, 0, 0, alpha: 0.1),
    routingruleIcon: hsl(240, 3.7, 37.5),
    routingruleTitle: hsl(240, 8, 9.8),
    routingruleTitleDisabled: hsl(240, 3.7, 37.5),
    routingruleSubtitle: hsl(240, 3.7, 37.5),

    // Application picker dialog
    apppickerIcon: hsl(240, 3.7, 37.5),
    apppickerDetail: hsl(240, 3.2, 42.9),
    apppickerSearchIcon: hsl(240, 3.7, 37.5),
    apppickerRowHover: hsl(240, 8, 9.8, alpha: 0.06),
    apppickerRowPressed: hsl(240, 8, 9.8, alpha: 0.12),

    // Diagnostics and logs
    diagnosticsbuttonBackground: hsl(0, 0, 95),
    logspreviewBackground: hsl(0, 0, 95),
    logspreviewHover: hsl(240, 8, 9.8, alpha: 0.06),
    logspreviewPressed: hsl(240, 8, 9.8, alpha: 0.12),
    logsdialogBackground: hsl(215, 10, 76, alpha: 0.28),

    // Updates section
    updatesstatusBackground: hsl(0, 0, 95),
    updatesstatusIcon: hsl(240, 3.7, 37.5),
    updatesstatusIconFound: hsl(208, 100, 50),
    updatesstatusText: hsl(240, 3.7, 37.5),
    updatesstatusTextFound: hsl(208, 100, 50),
    updatesnotesText: hsl(240, 3.7, 37.5),
    updatesprogressBar: hsl(208, 100, 50),
    updatesprogressTrack: hsl(0, 0, 100),
    updatescheckbuttonBackground: hsl(208, 100, 50),
    updatescheckbuttonText: hsl(0, 0, 100),
    updatesbuttonBackground: hsl(0, 0, 95),
  );

  // ======== DARK THEME ========
  static AppPalette _darkPalette() => AppPalette(
    brightness: Brightness.dark,

    // Page and plain widgets without their own colors below
    pageBackground: hsl(0, 0, 5),
    defaultSurface: hsl(0, 0, 10),
    defaultSurfaceDim: hsl(0, 0, 3.5),
    defaultText: hsl(0, 0, 80),
    defaultTextSecondary: hsl(0, 0, 60),
    defaultSecondary: hsl(0, 0, 84),
    defaultDisabled: hsl(0, 0, 44),
    defaultAccent: hsl(38, 92, 56),
    defaultOnAccent: hsl(32, 40, 8),
    defaultBorder: hsl(0, 0, 22),
    defaultBorderFaint: hsl(0, 0, 15),
    defaultDivider: hsl(0, 0, 25),
    defaultShadow: hsl(0, 0, 0, alpha: 0.3),
    defaultHover: hsl(0, 0, 96, alpha: 0.06),
    defaultPressed: hsl(0, 0, 96, alpha: 0.12),
    errorText: hsl(32, 90, 50),

    // Buttons
    buttonBackground: hsl(0, 0, 10),
    buttonText: hsl(0, 0, 80),
    buttonIcon: hsl(0, 0, 68),
    buttonIconDisabled: hsl(0, 0, 44),
    buttonInnerBorder: hsl(0, 0, 25, alpha: 0.2),

    // Connect button
    connectbuttonBackground: hsl(0, 0, 9),
    connectbuttonBackgroundOnCenter: hsl(38, 90, 50),
    connectbuttonBackgroundOnEdge: hsl(32, 50, 50),
    connectbuttonIcon: hsl(0, 0, 50),
    connectbuttonIconOn: hsl(0, 0, 10),
    connectbuttonTextBusy: hsl(0, 0, 44),
    connectbuttonSpinner: hsl(38, 92, 56),
    connectbuttonBorder: hsl(0, 0, 12),
    connectbuttonBorderOn: hsl(32, 50, 50),
    connectbuttonGlowOn: hsl(38, 100, 56, alpha: 0.4),
    connectbuttonInnerShade: hsl(0, 0, 9, alpha: 0.35),
    connectbuttonInnerShadeOn: hsl(0, 0, 0, alpha: 0.0),
    connectbuttonInnerLight: hsl(0, 0, 9, alpha: 0.35),
    connectbuttonInnerLightOn: hsl(0, 0, 100, alpha: 0.0),

    // Bottom navigation panel
    navpanelBackground: hsl(0, 0, 11, alpha: 0.75),
    navpanelOuterBorder: hsl(25, 0, 0, alpha: 0.2),
    navpanelInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    navpanelShadow: hsl(0, 0, 0, alpha: 0.3),
    navpanelHighlightBackgroundTop: hsl(32, 0, 20, alpha: 0.2),
    navpanelHighlightBackgroundBottom: hsl(32, 0, 20, alpha: 0.2),
    navpanelHighlightInnerBorder: hsl(0, 0, 20, alpha: 0.2),
    navpanelHighlightOuterBorder: hsl(0, 0, 0, alpha: 0.2),
    navpanelHighlightShadow: hsl(0, 0, 0, alpha: 0.1),
    navpanelIcon: hsl(0, 0, 68),
    navpanelIconSelected: hsl(38, 92, 56),
    navpanelIconGlow: hsl(38, 92, 56, alpha: 0.55),
    navpanelLabel: hsl(0, 0, 68),
    navpanelLabelSelected: hsl(0, 0, 96),
    navpanelItemHover: hsl(0, 0, 40, alpha: 0.05),

    // Round glass icon buttons (top bar, section actions)
    iconbuttonBackgroundTop: hsl(32, 0, 20, alpha: 0.2),
    iconbuttonBackgroundBottom: hsl(32, 0, 20, alpha: 0.2),
    iconbuttonInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    iconbuttonOuterBorder: null,
    iconbuttonShadow: hsl(0, 0, 0, alpha: 0.1),
    iconbuttonIcon: hsl(0, 0, 70),
    iconbuttonIconDisabled: hsl(0, 0, 44),
    iconbuttonIconSelected: hsl(38, 92, 56),
    iconbuttonIconWorking: hsl(40, 100, 50),
    iconbuttonHover: hsl(0, 0, 96, alpha: 0.06),
    iconbuttonPressed: hsl(0, 0, 96, alpha: 0.12),

    // Settings sections
    sectionBackground: hsl(0, 0, 10),
    sectionShadow: hsl(0, 0, 0, alpha: 0.3),
    sectionDivider: hsl(0, 0, 15),
    sectionTitle: hsl(0, 0, 80),
    sectionSubtitle: hsl(0, 0, 60),
    sectionLabel: hsl(0, 0, 55),
    sectionIcon: hsl(0, 0, 60),
    sectionIconOpen: hsl(38, 92, 56),
    sectionIconGlow: hsl(38, 92, 56, alpha: 0.45),
    sectionArrow: hsl(0, 0, 60),
    sectionArrowOpen: hsl(38, 92, 56),
    sectioniconboxBackgroundTop: hsl(32, 0, 20, alpha: 0.2),
    sectioniconboxBackgroundBottom: hsl(32, 0, 20, alpha: 0.2),
    sectioniconboxInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    sectioniconboxOuterBorder: null,
    sectioniconboxShadow: hsl(0, 0, 0, alpha: 0.1),
    settingsrowHover: hsl(0, 0, 96, alpha: 0.06),

    // Switches
    toggleTrackBackgroundTop: hsl(0, 0, 7),
    toggleTrackBackgroundBottom: hsl(0, 0, 12),
    toggleTrackBorder: hsl(0, 0, 15),
    toggleTrackHover: hsl(0, 0, 96, alpha: 0.06),
    toggleTrackPressed: hsl(0, 0, 96, alpha: 0.12),
    toggleTrackGlowStrong: hsl(38, 92, 56, alpha: 0.5),
    toggleTrackGlowSoft: hsl(38, 92, 56, alpha: 0.2),
    toggleKnobBackgroundTop: hsl(32, 0, 20, alpha: 0.2),
    toggleKnobBackgroundBottom: hsl(32, 0, 20, alpha: 0.2),
    toggleKnobOnBackgroundTop: hsl(32, 90, 50),
    toggleKnobOnBackgroundBottom: hsl(38, 92, 56),
    toggleKnobInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    toggleKnobShadow: hsl(0, 0, 0, alpha: 0.1),
    toggleKnobGlow: hsl(38, 92, 56, alpha: 0.5),

    // Select field
    selectBackground: hsl(0, 0, 10),
    selectValue: hsl(0, 0, 74),
    selectArrow: hsl(0, 0, 68),
    selectHover: hsl(0, 0, 96, alpha: 0.06),
    selectPressed: hsl(0, 0, 96, alpha: 0.12),
    selectInnerBorder: hsl(0, 0, 25, alpha: 0.2),

    // Select dropdown menu
    selectdropdownGlass: hsl(0, 0, 13, alpha: 0.7),
    selectdropdownOuterBorder: hsl(25, 0, 0, alpha: 0.2),
    selectdropdownInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    selectdropdownSeparator: hsl(0, 0, 15),
    selectdropdownItemText: hsl(0, 0, 80),
    selectdropdownItemSelected: hsl(0, 0, 96, alpha: 0.03),
    selectdropdownItemHover: hsl(0, 0, 96, alpha: 0.03),
    selectdropdownItemPressed: hsl(0, 0, 96, alpha: 0.12),

    // Dialogs
    dialogTitle: hsl(0, 0, 80),
    dialogSubtitle: hsl(0, 0, 80),
    dialogBackground: hsl(0, 0, 10, alpha: 0.75),
    dialogOuterBorder: hsl(25, 0, 0, alpha: 0.2),
    dialogInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    dialogLabel: hsl(0, 0, 70),
    dialogButtonBackground: hsl(0, 0, 50, alpha: 0.10),
    dialogInputBackground: hsl(0, 0, 50, alpha: 0.10),
    dialogInputHint: hsl(0, 0, 44),
    dialogSelectBackground: hsl(0, 0, 50, alpha: 0.10),
    dialogConfirmButton: hsl(208, 100, 56),
    dialogConfirmButtonText: hsl(0, 0, 90),
    dialogPasteButtonText: hsl(135, 59, 55),

    // Notifications
    notificationBackground: hsl(0, 0, 10, alpha: 0.75),
    notificationOuterBorder: hsl(25, 0, 0, alpha: 0.1),
    notificationInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    notificationIcon: hsl(0, 0, 68),
    notificationText: hsl(0, 0, 80),
    notificationCloseIcon: hsl(0, 0, 68),
    notificationCloseHover: hsl(0, 0, 96, alpha: 0.06),
    notificationClosePressed: hsl(0, 0, 96, alpha: 0.12),

    // Routing rule actions menu (opens from the settings button on a rule)
    routingactionsmenuBackground: hsl(0, 0, 10, alpha: 0.4),
    routingactionsmenuOuterBorder: hsl(25, 0, 0, alpha: 0.15),
    routingactionsmenuInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    routingactionsmenuIcon: hsl(0, 0, 68),
    routingactionsmenuIconDisabled: hsl(0, 0, 22),
    routingactionsmenuIconHover: hsl(0, 0, 68, alpha: 0.04),
    routingactionsmenuIconPressed: hsl(0, 0, 68, alpha: 0.1),

    // Warning notices
    warningBackground: hsl(38, 23.7, 13.7),
    warningIcon: hsl(32, 90, 50),
    warningText: hsl(32, 90, 50),

    // Main page server panel
    serverpanelBackground: hsl(0, 0, 10),
    serverpanelStatusText: hsl(0, 0, 68),
    serverpanelDivider: hsl(0, 0, 15),
    serverrowFallbackIcon: hsl(0, 0, 44),
    serverrowDetail: hsl(0, 0, 68),
    serverrowPing: hsl(0, 0, 68),

    // Protocol names in server details
    protocolHysteria2: hsl(268, 60, 72),
    protocolVless: hsl(213, 75, 68),
    protocolTrojan: hsl(27, 80, 64),
    protocolShadowsocks: hsl(169, 60, 58),
    protocolVmess: hsl(288, 55, 70),
    protocolUnknown: hsl(0, 0, 68),

    // Subscriptions page
    addsubscriptionbuttonBackground: hsl(0, 0, 10),
    addsubscriptionbuttonText: hsl(0, 0, 80),
    subscriptionrowBackground: hsl(0, 0, 10),
    subscriptionrowCheck: hsl(38, 92, 56),
    subscriptiondescriptionBackground: hsl(0, 0, 10),
    subscriptiondescriptionIcon: hsl(0, 0, 68),
    subscriptiondescriptionLabel: hsl(0, 0, 68),
    subscriptiontimingBackground: hsl(0, 0, 10),
    subscriptiontimingIcon: hsl(0, 0, 68),
    subscriptiontimingLabel: hsl(0, 0, 68),
    subscriptiontimingDetail: hsl(0, 0, 68),

    // Routing page
    addrulebuttonBackground: hsl(0, 0, 10),
    routingruleBackground: hsl(0, 0, 10),
    routingruleiconboxBackgroundTop: hsl(32, 0, 20, alpha: 0.2),
    routingruleiconboxBackgroundBottom: hsl(32, 0, 20, alpha: 0.2),
    routingruleiconboxInnerBorder: hsl(0, 0, 25, alpha: 0.2),
    routingruleiconboxOuterBorder: null,
    routingruleiconboxShadow: hsl(0, 0, 0, alpha: 0.1),
    routingruleIcon: hsl(0, 0, 68),
    routingruleTitle: hsl(0, 0, 80),
    routingruleTitleDisabled: hsl(0, 0, 68),
    routingruleSubtitle: hsl(0, 0, 68),

    // Application picker dialog
    apppickerIcon: hsl(0, 0, 68),
    apppickerDetail: hsl(0, 0, 60),
    apppickerSearchIcon: hsl(0, 0, 68),
    apppickerRowHover: hsl(0, 0, 96, alpha: 0.06),
    apppickerRowPressed: hsl(0, 0, 96, alpha: 0.12),

    // Diagnostics and logs
    diagnosticsbuttonBackground: hsl(0, 0, 13),
    logspreviewBackground: hsl(0, 0, 13),
    logspreviewHover: hsl(0, 0, 30, alpha: 0.05),
    logspreviewPressed: hsl(0, 0, 96, alpha: 0.12),
    logsdialogBackground: hsl(0, 0, 40, alpha: 0.10),

    // Updates section
    updatesstatusBackground: hsl(0, 0, 15),
    updatesstatusIcon: hsl(0, 0, 68),
    updatesstatusIconFound: hsl(208, 100, 56),
    updatesstatusText: hsl(0, 0, 68),
    updatesstatusTextFound: hsl(208, 100, 56),
    updatesnotesText: hsl(0, 0, 68),
    updatesprogressBar: hsl(208, 100, 56),
    updatesprogressTrack: hsl(0, 0, 10),
    updatescheckbuttonBackground: hsl(208, 100, 56),
    updatescheckbuttonText: hsl(0, 0, 100),
    updatesbuttonBackground: hsl(0, 0, 15),
  );

  /// The palette in use. Set by the app from the system's light or dark
  /// setting before it builds; everything below reads from it.
  static AppPalette current = light;
  static bool get isDark => current.brightness == Brightness.dark;

  /// Creates both palettes again from the values above, keeping the active
  /// theme. Hot reload keeps existing static values, so without this an edited
  /// color would only appear after a restart.
  static void reloadPalettes() {
    final wasDark = isDark;
    light = _lightPalette();
    dark = _darkPalette();
    current = wasDark ? dark : light;
  }

  static Color get pageBackground => current.pageBackground;
  static Color get defaultSurface => current.defaultSurface;
  static Color get defaultSurfaceDim => current.defaultSurfaceDim;
  static Color get defaultText => current.defaultText;
  static Color get defaultTextSecondary => current.defaultTextSecondary;
  static Color get defaultSecondary => current.defaultSecondary;
  static Color get defaultDisabled => current.defaultDisabled;
  static Color get defaultAccent => current.defaultAccent;
  static Color get defaultOnAccent => current.defaultOnAccent;
  static Color get defaultBorder => current.defaultBorder;
  static Color get defaultBorderFaint => current.defaultBorderFaint;
  static Color get defaultDivider => current.defaultDivider;
  static Color get defaultShadow => current.defaultShadow;
  static Color get defaultHover => current.defaultHover;
  static Color get defaultPressed => current.defaultPressed;
  static Color get errorText => current.errorText;
  static Color get buttonBackground => current.buttonBackground;
  static Color get buttonText => current.buttonText;
  static Color get buttonIcon => current.buttonIcon;
  static Color get buttonIconDisabled => current.buttonIconDisabled;
  static Color get buttonInnerBorder => current.buttonInnerBorder;
  static Color get connectbuttonBackground => current.connectbuttonBackground;
  static Color get connectbuttonBackgroundOnCenter =>
      current.connectbuttonBackgroundOnCenter;
  static Color get connectbuttonBackgroundOnEdge =>
      current.connectbuttonBackgroundOnEdge;
  static Color get connectbuttonIcon => current.connectbuttonIcon;
  static Color get connectbuttonIconOn => current.connectbuttonIconOn;
  static Color get connectbuttonTextBusy => current.connectbuttonTextBusy;
  static Color get connectbuttonSpinner => current.connectbuttonSpinner;
  static Color get connectbuttonBorder => current.connectbuttonBorder;
  static Color get connectbuttonBorderOn => current.connectbuttonBorderOn;
  static Color get connectbuttonGlowOn => current.connectbuttonGlowOn;
  static Color get connectbuttonInnerShade => current.connectbuttonInnerShade;
  static Color get connectbuttonInnerShadeOn =>
      current.connectbuttonInnerShadeOn;
  static Color get connectbuttonInnerLight => current.connectbuttonInnerLight;
  static Color get connectbuttonInnerLightOn =>
      current.connectbuttonInnerLightOn;
  static Color get navpanelBackground => current.navpanelBackground;
  static Color get navpanelOuterBorder => current.navpanelOuterBorder;
  static Color get navpanelInnerBorder => current.navpanelInnerBorder;
  static Color get navpanelShadow => current.navpanelShadow;
  static Color get navpanelHighlightBackgroundTop =>
      current.navpanelHighlightBackgroundTop;
  static Color get navpanelHighlightBackgroundBottom =>
      current.navpanelHighlightBackgroundBottom;
  static Color get navpanelHighlightInnerBorder =>
      current.navpanelHighlightInnerBorder;
  static Color? get navpanelHighlightOuterBorder =>
      current.navpanelHighlightOuterBorder;
  static Color get navpanelHighlightShadow => current.navpanelHighlightShadow;
  static Color get navpanelIcon => current.navpanelIcon;
  static Color get navpanelIconSelected => current.navpanelIconSelected;
  static Color get navpanelIconGlow => current.navpanelIconGlow;
  static Color get navpanelLabel => current.navpanelLabel;
  static Color get navpanelLabelSelected => current.navpanelLabelSelected;
  static Color get navpanelItemHover => current.navpanelItemHover;
  static Color get iconbuttonBackgroundTop => current.iconbuttonBackgroundTop;
  static Color get iconbuttonBackgroundBottom =>
      current.iconbuttonBackgroundBottom;
  static Color get iconbuttonInnerBorder => current.iconbuttonInnerBorder;
  static Color? get iconbuttonOuterBorder => current.iconbuttonOuterBorder;
  static Color get iconbuttonShadow => current.iconbuttonShadow;
  static Color get iconbuttonIcon => current.iconbuttonIcon;
  static Color get iconbuttonIconDisabled => current.iconbuttonIconDisabled;
  static Color get iconbuttonIconSelected => current.iconbuttonIconSelected;
  static Color get iconbuttonIconWorking => current.iconbuttonIconWorking;
  static Color get iconbuttonHover => current.iconbuttonHover;
  static Color get iconbuttonPressed => current.iconbuttonPressed;
  static Color get sectionBackground => current.sectionBackground;
  static Color get sectionShadow => current.sectionShadow;
  static Color get sectionDivider => current.sectionDivider;
  static Color get sectionTitle => current.sectionTitle;
  static Color get sectionSubtitle => current.sectionSubtitle;
  static Color get sectionLabel => current.sectionLabel;
  static Color get sectionIcon => current.sectionIcon;
  static Color get sectionIconOpen => current.sectionIconOpen;
  static Color get sectionIconGlow => current.sectionIconGlow;
  static Color get sectionArrow => current.sectionArrow;
  static Color get sectionArrowOpen => current.sectionArrowOpen;
  static Color get sectioniconboxBackgroundTop =>
      current.sectioniconboxBackgroundTop;
  static Color get sectioniconboxBackgroundBottom =>
      current.sectioniconboxBackgroundBottom;
  static Color get sectioniconboxInnerBorder =>
      current.sectioniconboxInnerBorder;
  static Color? get sectioniconboxOuterBorder =>
      current.sectioniconboxOuterBorder;
  static Color get sectioniconboxShadow => current.sectioniconboxShadow;
  static Color get settingsrowHover => current.settingsrowHover;
  static Color get toggleTrackBackgroundTop => current.toggleTrackBackgroundTop;
  static Color get toggleTrackBackgroundBottom =>
      current.toggleTrackBackgroundBottom;
  static Color get toggleTrackBorder => current.toggleTrackBorder;
  static Color get toggleTrackHover => current.toggleTrackHover;
  static Color get toggleTrackPressed => current.toggleTrackPressed;
  static Color get toggleTrackGlowStrong => current.toggleTrackGlowStrong;
  static Color get toggleTrackGlowSoft => current.toggleTrackGlowSoft;
  static Color get toggleKnobBackgroundTop => current.toggleKnobBackgroundTop;
  static Color get toggleKnobBackgroundBottom =>
      current.toggleKnobBackgroundBottom;
  static Color get toggleKnobOnBackgroundTop =>
      current.toggleKnobOnBackgroundTop;
  static Color get toggleKnobOnBackgroundBottom =>
      current.toggleKnobOnBackgroundBottom;
  static Color get toggleKnobInnerBorder => current.toggleKnobInnerBorder;
  static Color get toggleKnobShadow => current.toggleKnobShadow;
  static Color get toggleKnobGlow => current.toggleKnobGlow;
  static Color get selectBackground => current.selectBackground;
  static Color get selectValue => current.selectValue;
  static Color get selectArrow => current.selectArrow;
  static Color get selectHover => current.selectHover;
  static Color get selectPressed => current.selectPressed;
  static Color get selectInnerBorder => current.selectInnerBorder;
  static Color get selectdropdownGlass => current.selectdropdownGlass;
  static Color get selectdropdownOuterBorder =>
      current.selectdropdownOuterBorder;
  static Color get selectdropdownInnerBorder =>
      current.selectdropdownInnerBorder;
  static Color get selectdropdownSeparator => current.selectdropdownSeparator;
  static Color get selectdropdownItemText => current.selectdropdownItemText;
  static Color get selectdropdownItemSelected =>
      current.selectdropdownItemSelected;
  static Color get selectdropdownItemHover => current.selectdropdownItemHover;
  static Color get selectdropdownItemPressed =>
      current.selectdropdownItemPressed;
  static Color get dialogTitle => current.dialogTitle;
  static Color get dialogSubtitle => current.dialogSubtitle;
  static Color get dialogBackground => current.dialogBackground;
  static Color get dialogOuterBorder => current.dialogOuterBorder;
  static Color get dialogInnerBorder => current.dialogInnerBorder;
  static Color get dialogLabel => current.dialogLabel;
  static Color get dialogButtonBackground => current.dialogButtonBackground;
  static Color get dialogInputBackground => current.dialogInputBackground;
  static Color get dialogInputHint => current.dialogInputHint;
  static Color get dialogSelectBackground => current.dialogSelectBackground;
  static Color get dialogConfirmButton => current.dialogConfirmButton;
  static Color get dialogConfirmButtonText => current.dialogConfirmButtonText;
  static Color get dialogPasteButtonText => current.dialogPasteButtonText;
  static Color get notificationBackground => current.notificationBackground;
  static Color get notificationOuterBorder => current.notificationOuterBorder;
  static Color get notificationInnerBorder => current.notificationInnerBorder;
  static Color get notificationIcon => current.notificationIcon;
  static Color get notificationText => current.notificationText;
  static Color get notificationCloseIcon => current.notificationCloseIcon;
  static Color get notificationCloseHover => current.notificationCloseHover;
  static Color get notificationClosePressed => current.notificationClosePressed;
  static Color get routingactionsmenuBackground =>
      current.routingactionsmenuBackground;
  static Color get routingactionsmenuOuterBorder =>
      current.routingactionsmenuOuterBorder;
  static Color get routingactionsmenuInnerBorder =>
      current.routingactionsmenuInnerBorder;
  static Color get warningBackground => current.warningBackground;
  static Color get warningIcon => current.warningIcon;
  static Color get warningText => current.warningText;
  static Color get serverpanelBackground => current.serverpanelBackground;
  static Color get serverpanelStatusText => current.serverpanelStatusText;
  static Color get serverpanelDivider => current.serverpanelDivider;
  static Color get serverrowFallbackIcon => current.serverrowFallbackIcon;
  static Color get serverrowDetail => current.serverrowDetail;
  static Color get serverrowPing => current.serverrowPing;
  static Color get protocolHysteria2 => current.protocolHysteria2;
  static Color get protocolVless => current.protocolVless;
  static Color get protocolTrojan => current.protocolTrojan;
  static Color get protocolShadowsocks => current.protocolShadowsocks;
  static Color get protocolVmess => current.protocolVmess;
  static Color get protocolUnknown => current.protocolUnknown;
  static Color get subscriptionrowBackground =>
      current.subscriptionrowBackground;
  static Color get addsubscriptionbuttonBackground =>
      current.addsubscriptionbuttonBackground;
  static Color get addsubscriptionbuttonText =>
      current.addsubscriptionbuttonText;
  static Color get subscriptionrowCheck => current.subscriptionrowCheck;
  static Color get subscriptiondescriptionBackground =>
      current.subscriptiondescriptionBackground;
  static Color get subscriptiondescriptionIcon =>
      current.subscriptiondescriptionIcon;
  static Color get subscriptiondescriptionLabel =>
      current.subscriptiondescriptionLabel;
  static Color get subscriptiontimingBackground =>
      current.subscriptiontimingBackground;
  static Color get subscriptiontimingIcon => current.subscriptiontimingIcon;
  static Color get subscriptiontimingLabel => current.subscriptiontimingLabel;
  static Color get subscriptiontimingDetail => current.subscriptiontimingDetail;
  static Color get addrulebuttonBackground => current.addrulebuttonBackground;
  static Color get routingruleBackground => current.routingruleBackground;
  static Color get routingruleiconboxBackgroundTop =>
      current.routingruleiconboxBackgroundTop;
  static Color get routingruleiconboxBackgroundBottom =>
      current.routingruleiconboxBackgroundBottom;
  static Color get routingruleiconboxInnerBorder =>
      current.routingruleiconboxInnerBorder;
  static Color? get routingruleiconboxOuterBorder =>
      current.routingruleiconboxOuterBorder;
  static Color get routingruleiconboxShadow => current.routingruleiconboxShadow;
  static Color get routingruleIcon => current.routingruleIcon;
  static Color get routingruleTitle => current.routingruleTitle;
  static Color get routingruleTitleDisabled => current.routingruleTitleDisabled;
  static Color get routingruleSubtitle => current.routingruleSubtitle;
  static Color get routingactionsmenuIcon => current.routingactionsmenuIcon;
  static Color get routingactionsmenuIconDisabled =>
      current.routingactionsmenuIconDisabled;
  static Color get routingactionsmenuIconHover =>
      current.routingactionsmenuIconHover;
  static Color get routingactionsmenuIconPressed =>
      current.routingactionsmenuIconPressed;
  static Color get apppickerIcon => current.apppickerIcon;
  static Color get apppickerDetail => current.apppickerDetail;
  static Color get apppickerSearchIcon => current.apppickerSearchIcon;
  static Color get apppickerRowHover => current.apppickerRowHover;
  static Color get apppickerRowPressed => current.apppickerRowPressed;
  static Color get diagnosticsbuttonBackground =>
      current.diagnosticsbuttonBackground;
  static Color get logspreviewBackground => current.logspreviewBackground;
  static Color get logspreviewHover => current.logspreviewHover;
  static Color get logspreviewPressed => current.logspreviewPressed;
  static Color get logsdialogBackground => current.logsdialogBackground;
  static Color get updatesstatusBackground => current.updatesstatusBackground;
  static Color get updatesstatusIcon => current.updatesstatusIcon;
  static Color get updatesstatusIconFound => current.updatesstatusIconFound;
  static Color get updatesstatusText => current.updatesstatusText;
  static Color get updatesstatusTextFound => current.updatesstatusTextFound;
  static Color get updatesnotesText => current.updatesnotesText;
  static Color get updatesprogressBar => current.updatesprogressBar;
  static Color get updatesprogressTrack => current.updatesprogressTrack;
  static Color get updatescheckbuttonBackground =>
      current.updatescheckbuttonBackground;
  static Color get updatescheckbuttonText => current.updatescheckbuttonText;
  static Color get updatesbuttonBackground => current.updatesbuttonBackground;
}

/// One theme's colors. The values are in [AppColors].
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.pageBackground,
    required this.defaultSurface,
    required this.defaultSurfaceDim,
    required this.defaultText,
    required this.defaultTextSecondary,
    required this.defaultSecondary,
    required this.defaultDisabled,
    required this.defaultAccent,
    required this.defaultOnAccent,
    required this.defaultBorder,
    required this.defaultBorderFaint,
    required this.defaultDivider,
    required this.defaultShadow,
    required this.defaultHover,
    required this.defaultPressed,
    required this.errorText,
    required this.buttonBackground,
    required this.buttonText,
    required this.buttonIcon,
    required this.buttonIconDisabled,
    required this.buttonInnerBorder,
    required this.connectbuttonBackground,
    required this.connectbuttonBackgroundOnCenter,
    required this.connectbuttonBackgroundOnEdge,
    required this.connectbuttonIcon,
    required this.connectbuttonIconOn,
    required this.connectbuttonTextBusy,
    required this.connectbuttonSpinner,
    required this.connectbuttonBorder,
    required this.connectbuttonBorderOn,
    required this.connectbuttonGlowOn,
    required this.connectbuttonInnerShade,
    required this.connectbuttonInnerShadeOn,
    required this.connectbuttonInnerLight,
    required this.connectbuttonInnerLightOn,
    required this.navpanelBackground,
    required this.navpanelOuterBorder,
    required this.navpanelInnerBorder,
    required this.navpanelShadow,
    required this.navpanelHighlightBackgroundTop,
    required this.navpanelHighlightBackgroundBottom,
    required this.navpanelHighlightInnerBorder,
    required this.navpanelHighlightOuterBorder,
    required this.navpanelHighlightShadow,
    required this.navpanelIcon,
    required this.navpanelIconSelected,
    required this.navpanelIconGlow,
    required this.navpanelLabel,
    required this.navpanelLabelSelected,
    required this.navpanelItemHover,
    required this.iconbuttonBackgroundTop,
    required this.iconbuttonBackgroundBottom,
    required this.iconbuttonInnerBorder,
    required this.iconbuttonOuterBorder,
    required this.iconbuttonShadow,
    required this.iconbuttonIcon,
    required this.iconbuttonIconDisabled,
    required this.iconbuttonIconSelected,
    required this.iconbuttonIconWorking,
    required this.iconbuttonHover,
    required this.iconbuttonPressed,
    required this.sectionBackground,
    required this.sectionShadow,
    required this.sectionDivider,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.sectionLabel,
    required this.sectionIcon,
    required this.sectionIconOpen,
    required this.sectionIconGlow,
    required this.sectionArrow,
    required this.sectionArrowOpen,
    required this.sectioniconboxBackgroundTop,
    required this.sectioniconboxBackgroundBottom,
    required this.sectioniconboxInnerBorder,
    required this.sectioniconboxOuterBorder,
    required this.sectioniconboxShadow,
    required this.settingsrowHover,
    required this.toggleTrackBackgroundTop,
    required this.toggleTrackBackgroundBottom,
    required this.toggleTrackBorder,
    required this.toggleTrackHover,
    required this.toggleTrackPressed,
    required this.toggleTrackGlowStrong,
    required this.toggleTrackGlowSoft,
    required this.toggleKnobBackgroundTop,
    required this.toggleKnobBackgroundBottom,
    required this.toggleKnobOnBackgroundTop,
    required this.toggleKnobOnBackgroundBottom,
    required this.toggleKnobInnerBorder,
    required this.toggleKnobShadow,
    required this.toggleKnobGlow,
    required this.selectBackground,
    required this.selectValue,
    required this.selectArrow,
    required this.selectHover,
    required this.selectPressed,
    required this.selectInnerBorder,
    required this.selectdropdownGlass,
    required this.selectdropdownOuterBorder,
    required this.selectdropdownInnerBorder,
    required this.selectdropdownSeparator,
    required this.selectdropdownItemText,
    required this.selectdropdownItemSelected,
    required this.selectdropdownItemHover,
    required this.selectdropdownItemPressed,
    required this.dialogTitle,
    required this.dialogSubtitle,
    required this.dialogBackground,
    required this.dialogOuterBorder,
    required this.dialogInnerBorder,
    required this.dialogLabel,
    required this.dialogButtonBackground,
    required this.dialogInputBackground,
    required this.dialogInputHint,
    required this.dialogSelectBackground,
    required this.dialogConfirmButton,
    required this.dialogConfirmButtonText,
    required this.dialogPasteButtonText,
    required this.notificationBackground,
    required this.notificationOuterBorder,
    required this.notificationInnerBorder,
    required this.notificationIcon,
    required this.notificationText,
    required this.notificationCloseIcon,
    required this.notificationCloseHover,
    required this.notificationClosePressed,
    required this.routingactionsmenuBackground,
    required this.routingactionsmenuOuterBorder,
    required this.routingactionsmenuInnerBorder,
    required this.warningBackground,
    required this.warningIcon,
    required this.warningText,
    required this.serverpanelBackground,
    required this.serverpanelStatusText,
    required this.serverpanelDivider,
    required this.serverrowFallbackIcon,
    required this.serverrowDetail,
    required this.serverrowPing,
    required this.protocolHysteria2,
    required this.protocolVless,
    required this.protocolTrojan,
    required this.protocolShadowsocks,
    required this.protocolVmess,
    required this.protocolUnknown,
    required this.subscriptionrowBackground,
    required this.addsubscriptionbuttonBackground,
    required this.addsubscriptionbuttonText,
    required this.subscriptionrowCheck,
    required this.subscriptiondescriptionBackground,
    required this.subscriptiondescriptionIcon,
    required this.subscriptiondescriptionLabel,
    required this.subscriptiontimingBackground,
    required this.subscriptiontimingIcon,
    required this.subscriptiontimingLabel,
    required this.subscriptiontimingDetail,
    required this.addrulebuttonBackground,
    required this.routingruleBackground,
    required this.routingruleiconboxBackgroundTop,
    required this.routingruleiconboxBackgroundBottom,
    required this.routingruleiconboxInnerBorder,
    required this.routingruleiconboxOuterBorder,
    required this.routingruleiconboxShadow,
    required this.routingruleIcon,
    required this.routingruleTitle,
    required this.routingruleTitleDisabled,
    required this.routingruleSubtitle,
    required this.routingactionsmenuIcon,
    required this.routingactionsmenuIconDisabled,
    required this.routingactionsmenuIconHover,
    required this.routingactionsmenuIconPressed,
    required this.apppickerIcon,
    required this.apppickerDetail,
    required this.apppickerSearchIcon,
    required this.apppickerRowHover,
    required this.apppickerRowPressed,
    required this.diagnosticsbuttonBackground,
    required this.logspreviewBackground,
    required this.logspreviewHover,
    required this.logspreviewPressed,
    required this.logsdialogBackground,
    required this.updatesstatusBackground,
    required this.updatesstatusIcon,
    required this.updatesstatusIconFound,
    required this.updatesstatusText,
    required this.updatesstatusTextFound,
    required this.updatesnotesText,
    required this.updatesprogressBar,
    required this.updatesprogressTrack,
    required this.updatescheckbuttonBackground,
    required this.updatescheckbuttonText,
    required this.updatesbuttonBackground,
  });

  final Brightness brightness;
  final Color pageBackground;
  final Color defaultSurface;
  final Color defaultSurfaceDim;
  final Color defaultText;
  final Color defaultTextSecondary;
  final Color defaultSecondary;
  final Color defaultDisabled;
  final Color defaultAccent;
  final Color defaultOnAccent;
  final Color defaultBorder;
  final Color defaultBorderFaint;
  final Color defaultDivider;
  final Color defaultShadow;
  final Color defaultHover;
  final Color defaultPressed;
  final Color errorText;
  final Color buttonBackground;
  final Color buttonText;
  final Color buttonIcon;
  final Color buttonIconDisabled;
  final Color buttonInnerBorder;
  final Color connectbuttonBackground;
  final Color connectbuttonBackgroundOnCenter;
  final Color connectbuttonBackgroundOnEdge;
  final Color connectbuttonIcon;
  final Color connectbuttonIconOn;
  final Color connectbuttonTextBusy;
  final Color connectbuttonSpinner;
  final Color connectbuttonBorder;
  final Color connectbuttonBorderOn;
  final Color connectbuttonGlowOn;
  final Color connectbuttonInnerShade;
  final Color connectbuttonInnerShadeOn;
  final Color connectbuttonInnerLight;
  final Color connectbuttonInnerLightOn;
  final Color navpanelBackground;
  final Color navpanelOuterBorder;
  final Color navpanelInnerBorder;
  final Color navpanelShadow;
  final Color navpanelHighlightBackgroundTop;
  final Color navpanelHighlightBackgroundBottom;
  final Color navpanelHighlightInnerBorder;
  final Color? navpanelHighlightOuterBorder;
  final Color navpanelHighlightShadow;
  final Color navpanelIcon;
  final Color navpanelIconSelected;
  final Color navpanelIconGlow;
  final Color navpanelLabel;
  final Color navpanelLabelSelected;
  final Color navpanelItemHover;
  final Color iconbuttonBackgroundTop;
  final Color iconbuttonBackgroundBottom;
  final Color iconbuttonInnerBorder;
  final Color? iconbuttonOuterBorder;
  final Color iconbuttonShadow;
  final Color iconbuttonIcon;
  final Color iconbuttonIconDisabled;
  final Color iconbuttonIconSelected;
  final Color iconbuttonIconWorking;
  final Color iconbuttonHover;
  final Color iconbuttonPressed;
  final Color sectionBackground;
  final Color sectionShadow;
  final Color sectionDivider;
  final Color sectionTitle;
  final Color sectionSubtitle;
  final Color sectionLabel;
  final Color sectionIcon;
  final Color sectionIconOpen;
  final Color sectionIconGlow;
  final Color sectionArrow;
  final Color sectionArrowOpen;
  final Color sectioniconboxBackgroundTop;
  final Color sectioniconboxBackgroundBottom;
  final Color sectioniconboxInnerBorder;
  final Color? sectioniconboxOuterBorder;
  final Color sectioniconboxShadow;
  final Color settingsrowHover;
  final Color toggleTrackBackgroundTop;
  final Color toggleTrackBackgroundBottom;
  final Color toggleTrackBorder;
  final Color toggleTrackHover;
  final Color toggleTrackPressed;
  final Color toggleTrackGlowStrong;
  final Color toggleTrackGlowSoft;
  final Color toggleKnobBackgroundTop;
  final Color toggleKnobBackgroundBottom;
  final Color toggleKnobOnBackgroundTop;
  final Color toggleKnobOnBackgroundBottom;
  final Color toggleKnobInnerBorder;
  final Color toggleKnobShadow;
  final Color toggleKnobGlow;
  final Color selectBackground;
  final Color selectValue;
  final Color selectArrow;
  final Color selectHover;
  final Color selectPressed;
  final Color selectInnerBorder;
  final Color selectdropdownGlass;
  final Color selectdropdownOuterBorder;
  final Color selectdropdownInnerBorder;
  final Color selectdropdownSeparator;
  final Color selectdropdownItemText;
  final Color selectdropdownItemSelected;
  final Color selectdropdownItemHover;
  final Color selectdropdownItemPressed;
  final Color dialogTitle;
  final Color dialogSubtitle;
  final Color dialogBackground;
  final Color dialogOuterBorder;
  final Color dialogInnerBorder;
  final Color dialogLabel;
  final Color dialogButtonBackground;
  final Color dialogInputBackground;
  final Color dialogInputHint;
  final Color dialogSelectBackground;
  final Color dialogConfirmButton;
  final Color dialogConfirmButtonText;
  final Color dialogPasteButtonText;
  final Color notificationBackground;
  final Color notificationOuterBorder;
  final Color notificationInnerBorder;
  final Color notificationIcon;
  final Color notificationText;
  final Color notificationCloseIcon;
  final Color notificationCloseHover;
  final Color notificationClosePressed;
  final Color routingactionsmenuBackground;
  final Color routingactionsmenuOuterBorder;
  final Color routingactionsmenuInnerBorder;
  final Color warningBackground;
  final Color warningIcon;
  final Color warningText;
  final Color serverpanelBackground;
  final Color serverpanelStatusText;
  final Color serverpanelDivider;
  final Color serverrowFallbackIcon;
  final Color serverrowDetail;
  final Color serverrowPing;
  final Color protocolHysteria2;
  final Color protocolVless;
  final Color protocolTrojan;
  final Color protocolShadowsocks;
  final Color protocolVmess;
  final Color protocolUnknown;
  final Color subscriptionrowBackground;
  final Color addsubscriptionbuttonBackground;
  final Color addsubscriptionbuttonText;
  final Color subscriptionrowCheck;
  final Color subscriptiondescriptionBackground;
  final Color subscriptiondescriptionIcon;
  final Color subscriptiondescriptionLabel;
  final Color subscriptiontimingBackground;
  final Color subscriptiontimingIcon;
  final Color subscriptiontimingLabel;
  final Color subscriptiontimingDetail;
  final Color addrulebuttonBackground;
  final Color routingruleBackground;
  final Color routingruleiconboxBackgroundTop;
  final Color routingruleiconboxBackgroundBottom;
  final Color routingruleiconboxInnerBorder;
  final Color? routingruleiconboxOuterBorder;
  final Color routingruleiconboxShadow;
  final Color routingruleIcon;
  final Color routingruleTitle;
  final Color routingruleTitleDisabled;
  final Color routingruleSubtitle;
  final Color routingactionsmenuIcon;
  final Color routingactionsmenuIconDisabled;
  final Color routingactionsmenuIconHover;
  final Color routingactionsmenuIconPressed;
  final Color apppickerIcon;
  final Color apppickerDetail;
  final Color apppickerSearchIcon;
  final Color apppickerRowHover;
  final Color apppickerRowPressed;
  final Color diagnosticsbuttonBackground;
  final Color logspreviewBackground;
  final Color logspreviewHover;
  final Color logspreviewPressed;
  final Color logsdialogBackground;
  final Color updatesstatusBackground;
  final Color updatesstatusIcon;
  final Color updatesstatusIconFound;
  final Color updatesstatusText;
  final Color updatesstatusTextFound;
  final Color updatesnotesText;
  final Color updatesprogressBar;
  final Color updatesprogressTrack;
  final Color updatescheckbuttonBackground;
  final Color updatescheckbuttonText;
  final Color updatesbuttonBackground;
}
