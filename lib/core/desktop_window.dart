// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/services.dart';

/// Small UTF-8 channel to the Rust window host; no native plugin is required.
class DesktopWindow {
  static const channel = BasicMessageChannel<String>(
    'aora/window',
    StringCodec(),
  );
  bool get supported => Platform.isWindows;
  bool _ready = false;
  bool _disposed = false;
  bool? _canDisconnect;
  Future<void>? _exit;

  Future<void> initialize({
    required Future<void> Function() onExit,
    required Future<void> Function() onDisconnect,
    required void Function(Object error) onError,
  }) async {
    if (!supported) return;
    channel.setMessageHandler((message) async {
      if (_disposed) return 'unavailable';
      try {
        if (message == 'exit') {
          await (_exit ??= onExit());
        } else if (message == 'disconnect') {
          await onDisconnect();
        } else {
          return 'unsupported';
        }
        return 'ok';
      } catch (error) {
        _exit = null;
        // Make failures visible instead of leaving an inaccessible hidden app.
        try {
          await command('show');
        } catch (_) {}
        if (!_disposed) onError(error);
        return 'error';
      }
    });
    _ready = await channel.send('ready') == 'ok';
  }

  Future<void> command(String command) async {
    if (_disposed || !supported) return;
    final response = await channel.send(command);
    if (response != 'ok') {
      throw StateError(response ?? 'Desktop window controls are unavailable.');
    }
  }

  Future<void> setCanDisconnect(bool value) async {
    if (!_ready || _disposed || value == _canDisconnect) return;
    _canDisconnect = value;
    await command(value ? 'connected' : 'disconnected');
  }

  void dispose() {
    _disposed = true;
    if (supported) channel.setMessageHandler(null);
  }
}
