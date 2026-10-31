// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/app_paths.dart';

typedef StartupRequest = Future<Map<String, dynamic>> Function(
  Map<String, bool>? preferences,
);

class WindowsStartupController extends ChangeNotifier {
  WindowsStartupController({StartupRequest? request})
    : _request = request ?? _native;
  final StartupRequest _request;
  bool startWithWindows = false;
  bool startMinimized = false;
  bool busy = false;
  bool loaded = false;
  bool failed = false;
  bool _disposed = false;

  static Future<Map<String, dynamic>> _native(
    Map<String, bool>? preferences,
  ) async {
    final process = await Process.start(
      AppPaths.windowsHelper('aoravpn_service'),
      [preferences == null ? 'startup-status' : 'startup-set'],
    );
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    try {
      if (preferences != null) process.stdin.write(jsonEncode(preferences));
      await process.stdin.close();
      final code = await process.exitCode.timeout(const Duration(seconds: 20));
      final text = await output;
      final error = await errors;
      if (code != 0) throw StateError(error.trim());
      if (text.length > 4096) throw StateError('Invalid startup reply.');
      return jsonDecode(text) as Map<String, dynamic>;
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      throw StateError('Startup settings timed out.');
    }
  }

  Future<void> initialize() => _change(null);

  Future<void> update({bool? startWithWindows, bool? startMinimized}) async {
    if (!loaded) return;
    await _change({
      'startWithWindows': startWithWindows ?? this.startWithWindows,
      'startMinimized': startMinimized ?? this.startMinimized,
    });
  }

  Future<void> _change(Map<String, bool>? preferences) async {
    if (busy || _disposed) return;
    busy = true;
    failed = false;
    notifyListeners();
    try {
      final reply = await _request(preferences);
      if (reply['startWithWindows'] is! bool ||
          reply['startMinimized'] is! bool) {
        throw const FormatException('Invalid startup preferences.');
      }
      if (_disposed) return;
      startWithWindows = reply['startWithWindows'] as bool;
      startMinimized = reply['startMinimized'] as bool;
      loaded = true;
    } catch (_) {
      if (!_disposed) failed = true;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
