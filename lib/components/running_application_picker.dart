// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_dialog.dart';
import 'application_picker_dialog.dart';

Future<List<String>> loadRunningApplications() async {
  final ProcessResult result;
  final List<String> names;
  if (Platform.isWindows) {
    result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'@(Get-Process | Select-Object -ExpandProperty ProcessName -Unique) | ConvertTo-Json -Compress',
    ]).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) {
      throw StateError('Unable to read running applications.');
    }
    final decoded = jsonDecode(result.stdout as String);
    names = (decoded is List ? decoded : [decoded])
        .cast<String>()
        .where((name) => name != 'Idle' && name != 'System')
        .map((name) => '$name.exe')
        .toList();
  } else if (Platform.isLinux || Platform.isMacOS) {
    result = await Process.run('ps', [
      '-A',
      '-o',
      'comm=',
    ]).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) {
      throw StateError('Unable to read running applications.');
    }
    names = const LineSplitter()
        .convert(result.stdout as String)
        .map((name) => name.trim().split('/').last)
        .toList();
  } else {
    throw UnsupportedError(
      'Running application selection is available on desktop.',
    );
  }
  return names.where((name) => name.isNotEmpty).toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

Future<String?> showRunningApplicationPicker(BuildContext context) =>
    showAppDialog<String>(
      context: context,
      builder: (context) => ApplicationPickerDialog<String>(
        title: context.l10n.runningApplications,
        load: loadRunningApplications,
        label: (name) => name,
        result: (name) => name,
        loadFailed: context.l10n.runningLoadFailed,
      ),
    );
