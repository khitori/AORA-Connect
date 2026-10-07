// SPDX-License-Identifier: GPL-3.0-or-later

enum TunnelState { stopped, starting, running, stopping }

abstract interface class TunnelEngine {
  TunnelState get state;
  Stream<TunnelState> get states;
  Stream<String> get logs;
  Future<void> validate(String configPath);
  Future<void> start(String configPath);
  Future<void> stop();
  Future<void> dispose();
}
