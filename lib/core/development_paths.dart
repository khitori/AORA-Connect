// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/app_paths.dart';
import 'project_directory.dart';
export 'project_directory.dart';

Directory findCoreRoot() => Platform.isWindows && kReleaseMode
    ? AppPaths.windowsRoot
    : findProjectDirectory();
