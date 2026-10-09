// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/services.dart';

/// One writable root for settings and credential-bearing session files.
class AppPaths {
  static Directory get windowsRoot {
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) {
      throw StateError('Could not find the Windows local app data directory.');
    }
    return Directory('$base/AORAConnect');
  }

  static Future<Directory> root() async {
    if (Platform.isWindows) return windowsRoot;
    if (Platform.isAndroid) {
      const channel = MethodChannel('aoravpn/app_data');
      final path = await channel.invokeMethod<String>('filesDirectory');
      if (path == null || path.isEmpty) {
        throw StateError('Could not find the app data directory.');
      }
      return Directory(path);
    }
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      final config = Platform.environment['XDG_CONFIG_HOME'];
      final base = config != null && config.startsWith('/')
          ? config
          : home == null || home.isEmpty
          ? null
          : '$home/.config';
      if (base == null) {
        throw StateError('Could not find the Linux config directory.');
      }
      return Directory('$base/AORAConnect');
    }
    throw UnsupportedError('App storage is not supported on this platform.');
  }

  static Future<Directory> createSession(String prefix) async {
    final location = await root();
    final runtime = Directory('${location.path}/runtime');
    await runtime.create(recursive: true);
    if (Platform.isLinux) {
      final result = await Process.run('chmod', [
        '700',
        '--',
        location.path,
        runtime.path,
      ]);
      if (result.exitCode != 0) {
        throw StateError('Could not secure runtime storage.');
      }
    }
    return runtime.createTemp(prefix);
  }
}
