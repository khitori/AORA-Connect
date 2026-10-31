// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import '../l10n/locale_controller.dart';
import 'app_settings_store.dart';
import 'service_settings_document.dart';
import 'update_preferences_store.dart';

class WindowsAppSettingsStore implements AppSettingsStore {
  WindowsAppSettingsStore({
    ServiceSettingsDocument? document,
    this.legacyReader,
  }) : _document = document ?? ServiceSettingsDocument('app');
  final ServiceSettingsDocument _document;
  final Future<AppSettingsData?> Function()? legacyReader;
  @override
  Future<AppSettingsData> read() async {
    try {
      var missing = false;
      final data = await _document.read((value) {
        missing = value == null;
        return value == null
            ? const AppSettingsData()
            : AppSettingsData.fromJson(value);
      });
      if (!missing) return data;
      final legacy = await (legacyReader?.call() ?? _legacy());
      if (legacy == null) return data;
      await _document.write(legacy.toJson(), expectedRevision: 'missing');
      return legacy;
    } catch (_) {
      _document.invalidate();
      rethrow;
    }
  }

  static Future<AppSettingsData?> _legacy() async {
    final base = Platform.environment['APPDATA'];
    if (base == null || base.isEmpty) return null;
    final file = File('$base/AORAVPN/app-state.json');
    if (!await file.exists()) return null;
    if (await file.length() > 256 * 1024) {
      throw const FormatException('Legacy settings are too large.');
    }
    final data = AppSettingsData.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    return data;
  }

  @override
  Future<void> write(AppSettingsData data) => _document.write(data.toJson());
}

class WindowsLanguageStore implements LanguageStore {
  WindowsLanguageStore({ServiceSettingsDocument? document})
    : _document = document ?? ServiceSettingsDocument('language');
  final ServiceSettingsDocument _document;
  @override
  Future<String?> read() => _document.read(
    (value) =>
        value?['language'] is String ? value!['language'] as String : null,
  );
  @override
  Future<void> write(String? language) =>
      _document.write({'language': language});
}

class WindowsUpdatePreferencesStore implements UpdatePreferencesStore {
  WindowsUpdatePreferencesStore({ServiceSettingsDocument? document})
    : _document = document ?? ServiceSettingsDocument('updates');
  final ServiceSettingsDocument _document;
  @override
  Future<UpdatePreferencesData> read() =>
      _document.read(UpdatePreferencesData.fromJson);
  @override
  Future<void> write(UpdatePreferencesData value) =>
      _document.write(value.toJson());
}
