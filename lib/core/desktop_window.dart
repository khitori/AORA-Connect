// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/directional_text.dart';

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
  String? _labels;

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

  Future<void> setLabels(AppLocalizations strings) async {
    if (!_ready || _disposed) return;
    final labels =
        'localize:${jsonEncode({'show': strings.trayShow, 'disconnect': strings.disconnect, 'exit': strings.trayExit, 'rtl': isRtlLocale(strings)})}';
    if (_labels == labels) return;
    await command(labels);
    _labels = labels;
  }

  void dispose() {
    _disposed = true;
    if (supported) channel.setMessageHandler(null);
  }
}
