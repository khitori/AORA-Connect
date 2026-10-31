// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/storage/app_paths.dart';

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
  test('Development data stays inside the project build directory', () {
    if (!Platform.isWindows) return;
    expect(
      AppPaths.windowsRoot.path.replaceAll('\\', '/'),
      endsWith('/build/dev-data'),
    );
  });
}
