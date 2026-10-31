// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import '../storage/app_paths.dart';
import 'project_directory.dart';
export 'project_directory.dart';

Directory findCoreRoot() =>
    Platform.isWindows ? AppPaths.windowsRoot : findProjectDirectory();
