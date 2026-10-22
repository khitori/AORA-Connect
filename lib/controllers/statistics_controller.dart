// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/server_ping.dart';
import '../core/tunnel_engine.dart';
import 'connection_controller.dart';

typedef LatencyProbe = Future<Duration> Function(String address);

class LatencySample {
  const LatencySample(this.time, this.duration, {this.pending = false});

  final DateTime time;
  final Duration? duration;
  final bool pending;
}

class StatisticsController extends ChangeNotifier {
  StatisticsController(this.connection, {LatencyProbe? probe})
    : _probe = probe ?? pingServer {
    connection.addListener(_syncConnection);
    _syncConnection();
  }

  static const sampleInterval = Duration(seconds: 1);
  static const maxSamples = 30;

  final ConnectionController connection;
  final LatencyProbe _probe;
  final List<LatencySample> _samples = [];
  Timer? _timer;
  bool _active = false;
  int _pendingSamples = 0;
  String? _liveError;
  String? _address;
  bool _disposed = false;
  int _generation = 0;

  List<LatencySample> get samples => List.unmodifiable(_samples);
  bool get active => _active;
  bool get measuring => _pendingSamples > 0;
  String? get liveError => _liveError;
  Duration? get latest {
    for (final sample in _samples.reversed) {
      if (!sample.pending) return sample.duration;
    }
    return null;
  }

  int get completedSamples =>
      _samples.where((sample) => !sample.pending).length;
  int get successfulSamples =>
      _samples.where((sample) => sample.duration != null).length;

  void _syncConnection() {
    final shouldRun =
        connection.serverChecksSupported &&
        connection.statisticsEnabled &&
        connection.state == TunnelState.running &&
        connection.selected != null;
    final nextAddress = connection.selectedServerAddress;
    if (shouldRun == _active && nextAddress == _address) return;
    _address = nextAddress;
    _active = shouldRun;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _samples.clear();
    _pendingSamples = 0;
    _liveError = null;
    if (_active) {
      _timer = Timer.periodic(sampleInterval, (_) => unawaited(_measure()));
      unawaited(_measure());
    }
    _notify();
  }

  Future<void> _measure() async {
    if (!_active || _address == null) return;
    final generation = _generation;
    final sample = LatencySample(DateTime.now(), null, pending: true);
    _samples.add(sample);
    if (_samples.length > maxSamples) _samples.removeAt(0);
    _pendingSamples++;
    _notify();
    Duration? duration;
    String? errorMessage;
    try {
      duration = await _probe(_address!).timeout(const Duration(seconds: 5));
    } catch (error) {
      errorMessage = _message(error);
    } finally {
      if (!_disposed && _active && generation == _generation) {
        final index = _samples.indexOf(sample);
        if (index != -1) {
          _samples[index] = LatencySample(sample.time, duration);
          if (!_samples.skip(index + 1).any((sample) => !sample.pending)) {
            _liveError = errorMessage;
          }
        }
        _pendingSamples--;
        _notify();
      }
    }
  }

  String _message(Object error) => error is ServerPingException
      ? error.message
      : 'Could not check server ping.';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    connection.removeListener(_syncConnection);
    super.dispose();
  }
}
