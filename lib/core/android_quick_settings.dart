// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';

class AndroidQuickSettings {
  static const channel = MethodChannel('aora/quick_settings');

  static Future<String?> addTile() => channel.invokeMethod<String>('addTile');
  static Future<void> setBusy(bool busy, {String? expectedState}) =>
      channel.invokeMethod<void>('busy', {
        'busy': busy,
        'expectedState': expectedState,
      });
  static Future<void> save({
    String? config,
    String? core,
    String? name,
    String? host,
  }) => channel.invokeMethod<void>('save', {
    'config': config,
    'core': core,
    'name': name,
    'host': host,
  });
}
