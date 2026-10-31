// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import '../l10n/locale_controller.dart';
import 'app_settings_store.dart';
import 'update_preferences_store.dart';
import 'windows_settings_stores.dart';

AppSettingsStore createAppSettingsStore() =>
    Platform.isWindows ? WindowsAppSettingsStore() : FileAppSettingsStore();
LanguageStore createLanguageStore() =>
    Platform.isWindows ? WindowsLanguageStore() : FileLanguageStore();
UpdatePreferencesStore createUpdatePreferencesStore({Directory? directory}) =>
    Platform.isWindows && directory == null
    ? WindowsUpdatePreferencesStore()
    : FileUpdatePreferencesStore(directory: directory);
