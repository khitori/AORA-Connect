// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

Future<Directory> createTestRuntimeSession() =>
    Directory.systemTemp.createTemp('aora-test-profile-');
