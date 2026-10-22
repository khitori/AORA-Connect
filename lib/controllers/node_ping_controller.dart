// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/node_ping.dart';
import '../core/ping_type.dart';
import '../core/server_ping.dart';
import '../profiles/server_profile.dart';
import 'connection_controller.dart';

class NodePingResult {
  const NodePingResult({this.latency, this.error, this.pending = false});
  final Duration? latency;
  final String? error;
  final bool pending;
  String get label => pending
      ? '…'
      : latency == null
      ? error == 'Cancelled'
            ? '—'
            : error?.contains('UDP-only') == true
            ? 'N/A'
            : error == 'Timeout'
            ? 'Timeout'
            : 'Failed'
      : latency!.inMilliseconds == 0
      ? '<1 ms'
      : '${latency!.inMilliseconds} ms';
}

class NodePingController extends ChangeNotifier {
  NodePingController(
    this.connection, {
    NodePingProbe? probe,
    NodePingService? service,
  }) : _service = probe == null ? service ?? NodePingService() : null,
       _probe = probe {
    connection.addListener(_sync);
    _sync();
  }

  final ConnectionController connection;
  static const maxConcurrentChecks = 32;
  final NodePingService? _service;
  final NodePingProbe? _probe;
  final _results = <ServerProfile, NodePingResult>{};
  List<ServerProfile> _profiles = [];
  PingType? _type;
  PingCancellation? _cancellation;
  Future<void>? _operation;
  bool _disposed = false;
  int _generation = 0;
  int completed = 0;
  int checkingCount = 0;
  DateTime? lastCheckedAt;
  bool get busy => _operation != null;
  bool get canCheck =>
      connection.serverChecksSupported &&
      !connection.busy &&
      _profiles.isNotEmpty &&
      !busy;
  NodePingResult? resultFor(ServerProfile profile) => _results[profile];

  void _sync() {
    final profiles = connection.profiles;
    if (_type == connection.pingType && listEquals(_profiles, profiles)) return;
    cancel();
    _generation++;
    _profiles = profiles;
    _type = connection.pingType;
    _results.clear();
    completed = 0;
    checkingCount = 0;
    lastCheckedAt = null;
    _notify();
  }

  Future<void> checkSelected() {
    final selected = connection.selected;
    if (selected == null || !_profiles.contains(selected)) {
      return Future.value();
    }
    return _checkProfiles([selected]);
  }

  Future<void> checkAll() =>
      _checkProfiles(List.of(_profiles), clearResults: true);

  Future<void> _checkProfiles(
    List<ServerProfile> profiles, {
    bool clearResults = false,
  }) {
    if (!canCheck) return Future.value();
    final cancellation = PingCancellation();
    _cancellation = cancellation;
    final generation = ++_generation;
    final type = connection.pingType;
    completed = 0;
    checkingCount = profiles.length;
    if (clearResults) _results.clear();
    for (final profile in profiles) {
      _results[profile] = const NodePingResult(pending: true);
    }
    final operation = Future<void>(() async {
      NodePingBatch? batch;
      try {
        if (type.viaProxy && _service != null) {
          batch = await _service.openBatch(profiles, cancellation);
        }
        var next = 0;
        Future<void> worker() async {
          while (!cancellation.cancelled && next < profiles.length) {
            final profile = profiles[next++];
            NodePingResult result;
            try {
              final latency = await (batch != null
                  ? batch.check(profile, type, cancellation)
                  : (_probe ?? _service!.check)(profile, type, cancellation));
              result = NodePingResult(latency: latency);
            } catch (error) {
              result = NodePingResult(
                error: error is ServerPingException
                    ? error.message
                    : error is TimeoutException
                    ? 'Timeout'
                    : 'Server check failed.',
              );
            }
            if (_disposed ||
                cancellation.cancelled ||
                generation != _generation) {
              return;
            }
            _results[profile] = result;
            completed++;
            _notify();
          }
        }

        await Future.wait(
          List.generate(
            profiles.length < maxConcurrentChecks
                ? profiles.length
                : maxConcurrentChecks,
            (_) => worker(),
          ),
        );
      } catch (error) {
        if (!_disposed &&
            !cancellation.cancelled &&
            generation == _generation) {
          for (final profile in profiles) {
            _results[profile] = NodePingResult(
              error: error is ServerPingException
                  ? error.message
                  : 'Could not prepare server checks.',
            );
          }
          completed = profiles.length;
          _notify();
        }
      } finally {
        await batch?.dispose();
      }
    });
    _operation = operation;
    _notify();
    return operation.whenComplete(() {
      _operation = null;
      if (generation == _generation) {
        if (!cancellation.cancelled && completed == profiles.length) {
          lastCheckedAt = DateTime.now();
        }
        _cancellation = null;
        for (final profile in profiles) {
          if (_results[profile]?.pending == true) {
            _results[profile] = const NodePingResult(error: 'Cancelled');
          }
        }
      }
      _notify();
    });
  }

  void cancel() {
    _cancellation?.cancel();
    for (final entry in _results.entries.toList()) {
      if (entry.value.pending) {
        _results[entry.key] = const NodePingResult(error: 'Cancelled');
      }
    }
    _notify();
  }

  Future<void> shutdown() async {
    cancel();
    await _operation;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    connection.removeListener(_sync);
    _cancellation?.cancel();
    super.dispose();
  }
}
