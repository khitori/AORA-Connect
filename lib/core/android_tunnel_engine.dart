// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'tunnel_engine.dart';
import 'core_kind.dart';
import 'connection_diagnostics.dart';

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
  static Future<String> resolveServer(String host) async {
    final address = await channel
        .invokeMethod<String>('resolve', {'host': host})
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw StateError(
              'Server DNS lookup timed out on the selected physical network after 15 seconds.',
            );
          },
        );
    if (address == null || InternetAddress.tryParse(address) == null) {
      throw StateError('Server DNS lookup returned no usable IP address.');
    }
    return address;
  }

  static final _nativeEvents = events.receiveBroadcastStream();
  final CoreKind core;
  final _states = StreamController<TunnelState>.broadcast();
  final _logs = StreamController<String>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  late final Future<void> ready;
  TunnelState _state = TunnelState.stopped;
  String? _connectionSummary;

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
      final configuration = await File(configPath).readAsString();
      _connectionSummary = connectionConfigurationSummary(configuration, core);
      _logs.add(_connectionSummary!);
      await channel
          .invokeMethod<void>('start', {
            'config': configuration,
            'core': core.name,
          })
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              throw StateError(
                'Android VPN startup timed out after 90 seconds. Check the startup-stage logs in Diagnostics.',
              );
            },
          );
      _update('running');
    } catch (error) {
      if (error is! PlatformException || error.code != 'BUSY') {
        await captureDiagnostics();
        await stop();
      }
      rethrow;
    }
  }

  Future<void> captureDiagnostics() async {
    if (_connectionSummary != null) _logs.add(_connectionSummary!);
    try {
      final details = await channel
          .invokeMapMethod<String, dynamic>('diagnostics')
          .timeout(const Duration(seconds: 2));
      if (details?['network'] case final String network) {
        _logs.add('Connection check network: $network');
      }
      if (details?['coreError'] case final String error) {
        _logs.add('Last core error: $error');
      }
    } catch (_) {
      _logs.add('Connection check network: diagnostics unavailable.');
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
  }
}
