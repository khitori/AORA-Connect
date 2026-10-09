// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/controllers/statistics_controller.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/server_ping.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngine implements TunnelEngine {
  final _states = StreamController<TunnelState>.broadcast();
  final _logs = StreamController<String>.broadcast();
  TunnelState _state = TunnelState.stopped;

  void emit(TunnelState state) {
    _state = state;
    _states.add(state);
  }

  @override
  TunnelState get state => _state;
  @override
  Stream<TunnelState> get states => _states.stream;
  @override
  Stream<String> get logs => _logs.stream;
  @override
  Future<void> validate(String path) async {}
  @override
  Future<void> start(String path) async => emit(TunnelState.running);
  @override
  Future<void> stop() async => emit(TunnelState.stopped);
  @override
  Future<void> dispose() async {
    await _states.close();
    await _logs.close();
  }
}

void main() {
  testWidgets('Records one slot per second and keeps 30 during slow checks', (
    tester,
  ) async {
    final engine = _FakeEngine();
    final connection = ConnectionController(
      engine: engine,
      subscriptionLoader: (_) async => SubscriptionLoadResult(
        profiles: [
          HysteriaProfile(
            name: 'Server',
            server: '127.0.0.1',
            port: 443,
            password: 'secret',
            serverName: 'example.com',
          ),
        ],
      ),
    );
    await tester.runAsync(() async {
      await connection.addSubscription('https://example.com/sub');
    });
    var checks = 0;
    await connection.setStatisticsEnabled(true);
    final statistics = StatisticsController(
      connection,
      probe: (_) {
        checks++;
        if (checks == 1) {
          return Future.value(const Duration(milliseconds: 42));
        }
        return Completer<Duration>().future;
      },
    );
    engine.emit(TunnelState.running);
    await tester.pump();
    expect(statistics.samples, hasLength(1));
    expect(statistics.latest, const Duration(milliseconds: 42));
    for (var second = 1; second <= 35; second++) {
      await tester.pump(const Duration(seconds: 1));
      expect(statistics.samples.length, second < 30 ? second + 1 : 30);
      if (second == 1) {
        expect(statistics.samples.last.pending, isTrue);
        expect(statistics.latest, const Duration(milliseconds: 42));
        expect(statistics.completedSamples, 1);
      }
    }
    expect(checks, 36);
    expect(statistics.successfulSamples, 0);
    expect(statistics.latest, isNull);
    await connection.setStatisticsEnabled(false);
    expect(statistics.active, isFalse);
    expect(statistics.samples, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(checks, 36);
    await connection.setStatisticsEnabled(true);
    await tester.pump();
    expect(statistics.active, isTrue);
    expect(checks, 37);
    await tester.pump(const Duration(seconds: 1));
    expect(checks, 38);
    statistics.dispose();
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(connection.shutdown);
    connection.dispose();
  });

  test(
    'Failed live check is retained as a gap without a latency value',
    () async {
      final engine = _FakeEngine();
      final connection = ConnectionController(
        engine: engine,
        subscriptionLoader: (_) async => SubscriptionLoadResult(
          profiles: [
            HysteriaProfile(
              name: 'Server',
              server: '127.0.0.1',
              port: 443,
              password: 'secret',
              serverName: 'example.com',
            ),
          ],
        ),
      );
      await connection.addSubscription('https://example.com/sub');
      final statistics = StatisticsController(
        connection,
        probe: (_) async => throw const ServerPingException('No ICMP reply'),
      );
      engine.emit(TunnelState.running);
      await connection.setStatisticsEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(statistics.samples, hasLength(1));
      expect(statistics.latest, isNull);
      expect(statistics.liveError, 'No ICMP reply');
      statistics.dispose();
      await connection.shutdown();
      connection.dispose();
    },
  );

  test(
    'Live checks target selected server; sampling stops on disconnect',
    () async {
      final engine = _FakeEngine();
      final connection = ConnectionController(
        engine: engine,
        subscriptionLoader: (_) async => SubscriptionLoadResult(
          profiles: [
            HysteriaProfile(
              name: 'Server',
              server: '127.0.0.1',
              port: 443,
              password: 'secret',
              serverName: 'example.com',
            ),
          ],
        ),
      );
      final addresses = <String>[];
      final statistics = StatisticsController(
        connection,
        probe: (address) async {
          addresses.add(address);
          return const Duration(milliseconds: 42);
        },
      );
      await connection.addSubscription('https://example.com/sub');
      expect(addresses, isEmpty);
      await connection.setStatisticsEnabled(true);

      engine.emit(TunnelState.running);
      await Future<void>.delayed(Duration.zero);
      expect(statistics.active, isTrue);
      expect(statistics.samples, hasLength(1));
      expect(statistics.latest, const Duration(milliseconds: 42));
      expect(addresses, ['127.0.0.1']);

      engine.emit(TunnelState.stopped);
      await Future<void>.delayed(Duration.zero);
      expect(statistics.active, isFalse);
      expect(statistics.samples, isEmpty);
      statistics.dispose();
      await connection.shutdown();
      connection.dispose();
    },
  );
}
