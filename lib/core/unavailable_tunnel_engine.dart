// SPDX-License-Identifier: GPL-3.0-or-later
import 'tunnel_engine.dart';

class UnavailableTunnelEngine implements TunnelEngine {
  const UnavailableTunnelEngine();

  static const reason =
      'VPN connections are not available on this platform yet.';

  @override
  TunnelState get state => TunnelState.stopped;

  @override
  Stream<TunnelState> get states => const Stream.empty();

  @override
  Stream<String> get logs => const Stream.empty();

  @override
  Future<void> validate(String configPath) async =>
      throw UnsupportedError(reason);

  @override
  Future<void> start(String configPath) async => throw UnsupportedError(reason);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
