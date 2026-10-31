// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/windows_service_transport.dart';

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

  /// The service registers the sign-in task for the enrolled account.
  static Future<Map<String, dynamic>> _native(
    Map<String, bool>? preferences,
  ) async {
    await WindowsServiceTransport.start();
    final reply = await WindowsServiceTransport.request({
      'protocol': 1,
      'command': preferences == null ? 'startup.status' : 'startup.set',
      'preferences': ?preferences,
    });
    final startup = reply['startup'];
    if (reply['ok'] != true || startup is! Map<String, dynamic>) {
      throw StateError(
        reply['error'] as String? ?? 'Startup settings are unavailable.',
      );
    }
    return startup;
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
