// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/app_paths.dart';

Directory findCoreRoot() => Platform.isWindows && kReleaseMode
    ? AppPaths.windowsRoot
    : findProjectDirectory();

Directory findProjectDirectory() {
  for (final start in [
    Directory.current,
    File(Platform.resolvedExecutable).parent,
  ]) {
    var directory = start.absolute;
    while (true) {
      if (File('${directory.path}/configs/local-test.json').existsSync() &&
          File('${directory.path}/pubspec.yaml').existsSync()) {
        return directory;
      }
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
  }
  return Directory.current;
}
