// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/storage/app_paths.dart';
import 'package:aoravpn/storage/windows_installation.dart';

void main() {
  test(
    'Installed storage is relative to the app executable, not the user profile',
    () {
      final root = Directory(
        '${Directory.systemTemp.path}/Program Files/AORAConnect',
      );
      final resolved = AppPaths.windowsInstalledRoot(
        '${root.path}/app/aoravpn.exe',
      );
      expect(resolved.path, root.absolute.path);
      expect(Directory('${resolved.path}/cores').parent.path, resolved.path);
    },
  );
  test('Unpackaged release paths fail instead of silently using AppData', () {
    expect(
      () => AppPaths.windowsInstalledRoot(
        '${Directory.systemTemp.path}/aoravpn.exe',
      ),
      throwsStateError,
    );
  });
  test('Development shares installed storage and helpers', () {
    if (!Platform.isWindows) return;
    expect(
      AppPaths.windowsRoot.absolute.path,
      WindowsInstallation.root.absolute.path,
    );
    expect(
      AppPaths.windowsHelper('aoravpn_service').replaceAll('\\', '/'),
      endsWith('/AORAConnect/app/aoravpn_service.exe'),
    );
    final programFiles = Platform.environment['ProgramW6432'];
    if (programFiles != null) {
      expect(
        AppPaths.windowsRoot.absolute.path,
        Directory('$programFiles/AORAConnect').absolute.path,
      );
    }
  });
}
