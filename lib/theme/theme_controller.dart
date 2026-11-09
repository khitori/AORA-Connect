// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../storage/app_paths.dart';
import '../storage/service_settings_document.dart';

/// The theme chosen in Settings; [system] follows the device's setting.
enum ThemeChoice { system, light, dark }

ThemeChoice _choice(Object? name) => ThemeChoice.values.firstWhere(
  (value) => value.name == name,
  orElse: () => ThemeChoice.light,
);

abstract interface class ThemeStore {
  Future<ThemeChoice> read();
  Future<void> write(ThemeChoice choice);
}

ThemeStore createThemeStore() =>
    Platform.isWindows ? WindowsThemeStore() : FileThemeStore();

/// Kept by the Windows service, like the other settings.
class WindowsThemeStore implements ThemeStore {
  WindowsThemeStore({ServiceSettingsDocument? document})
    : _document = document ?? ServiceSettingsDocument('appearance');
  final ServiceSettingsDocument _document;
  bool _loaded = false;

  @override
  Future<ThemeChoice> read() async {
    final choice = await _document.read((value) => _choice(value?['theme']));
    _loaded = true;
    return choice;
  }

  @override
  Future<void> write(ThemeChoice choice) async {
    // The service only accepts a write after a read of the same document.
    if (!_loaded) await read();
    try {
      await _document.write({'theme': choice.name});
    } catch (_) {
      _loaded = false;
      rethrow;
    }
  }
}

class FileThemeStore implements ThemeStore {
  FileThemeStore({this.directory});
  final Directory? directory;

  Future<File> _file() async => File(
    '${directory?.path ?? '${(await AppPaths.root()).path}/settings'}'
    '/appearance.json',
  );

  @override
  Future<ThemeChoice> read() async {
    try {
      final json = jsonDecode(await (await _file()).readAsString());
      return _choice(json is Map ? json['theme'] : null);
    } on FileSystemException {
      return ThemeChoice.light;
    } on FormatException {
      return ThemeChoice.light;
    }
  }

  @override
  Future<void> write(ThemeChoice choice) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'theme': choice.name}),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController({this.store});
  final ThemeStore? store;

  ThemeChoice _choice = ThemeChoice.light;
  ThemeChoice get choice => _choice;
  bool _chosen = false;
  bool _disposed = false;

  /// Loads the saved choice. Until it arrives, or if it cannot be read, the
  /// app is light.
  Future<void> initialize() async {
    final ThemeChoice saved;
    try {
      saved = await store?.read() ?? ThemeChoice.light;
    } catch (_) {
      return;
    }
    if (_disposed || _chosen || saved == _choice) return;
    _choice = saved;
    notifyListeners();
  }

  /// Applies [choice] at once. A failure to save it is rethrown, but the
  /// theme still changes for this session.
  Future<void> select(ThemeChoice choice) async {
    _chosen = true;
    if (choice != _choice) {
      _choice = choice;
      notifyListeners();
    }
    await store?.write(choice);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
