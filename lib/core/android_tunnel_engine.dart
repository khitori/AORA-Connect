// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'tunnel_engine.dart';
import 'core_kind.dart';

/// Flutter is a client of the foreground service, not the VPN's lifetime owner.
class AndroidTunnelEngine implements TunnelEngine {
  AndroidTunnelEngine({this.core = CoreKind.singBox}) {
    _subscription = _nativeEvents.listen(
      (event) {
        final data = Map<Object?, Object?>.from(event as Map);
        if ((data['core'] ?? 'singBox') != core.name) return;
        if (data['state'] case final String value) _update(value);
        if (data['log'] case final String line) _logs.add(line);
      },
      onError: (Object error) => _logs.add('Android VPN event stream: $error'),
    );
    ready = _restoreState();
  }

  static const channel = MethodChannel('aora/vpn');
  static const events = EventChannel('aora/vpn/events');
  static final _nativeEvents = events.receiveBroadcastStream();
  final CoreKind core;
  final _states = StreamController<TunnelState>.broadcast();
  final _logs = StreamController<String>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  late final Future<void> ready;
  TunnelState _state = TunnelState.stopped;

  @override
  TunnelState get state => _state;
  @override
  Stream<TunnelState> get states => _states.stream;
  @override
  Stream<String> get logs => _logs.stream;

  void _update(String value) {
    final next = TunnelState.values.byName(value);
    if (next == _state) return;
    _state = next;
    _states.add(next);
  }

  Future<void> _restoreState() async {
    _update(
      await channel.invokeMethod<String>('status', {'core': core.name}) ??
          'stopped',
    );
  }

  @override
  Future<void> validate(String configPath) async {
    await ready;
    await channel.invokeMethod<void>('validate', {
      'config': await File(configPath).readAsString(),
      'core': core.name,
    });
  }

  @override
  Future<void> start(String configPath) async {
    await ready;
    try {
      await channel
          .invokeMethod<void>('start', {
            'config': await File(configPath).readAsString(),
            'core': core.name,
          })
          .timeout(const Duration(seconds: 90));
      _update('running');
    } catch (error) {
      // A rejected duplicate start does not own the already-running session.
      if (error is! PlatformException || error.code != 'BUSY') await stop();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    await channel
        .invokeMethod<void>('stop', {'core': core.name})
        .timeout(const Duration(seconds: 20));
    _update('stopped');
  }

  @override
  Future<void> dispose() async {
    await ready;
    await _subscription.cancel();
    await _states.close();
    await _logs.close();
    // Only explicit Disconnect stops the native service.
  }
}
