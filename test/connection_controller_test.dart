// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/core/tunnel_engine.dart';

class ControlledEngine implements TunnelEngine {
  final messages = StreamController<String>.broadcast();
  final changes = StreamController<TunnelState>.broadcast();
  Completer<void>? validationGate;
  bool rejectValidation = false;
  int disposalCalls = 0;
  @override
  TunnelState get state => TunnelState.stopped;
  @override
  Stream<String> get logs => messages.stream;
  @override
  Stream<TunnelState> get states => changes.stream;
  @override
  Future<void> validate(String path) async {
    await validationGate?.future;
    if (rejectValidation) throw StateError('Invalid configuration');
  }

  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposalCalls++;
    await messages.close();
    await changes.close();
  }
}

void main() {
  test('Validation failure exposes an error and re-enables controls', () async {
    final engine = ControlledEngine()..rejectValidation = true;
    final controller = ConnectionController(
      engine: engine,
      configPath: 'test.json',
    );
    await controller.validate();
    expect(controller.error, contains('Invalid configuration'));
    expect(controller.busy, isFalse);
    expect(controller.canConnect, isTrue);
    await controller.shutdown();
    controller.dispose();
  });

  test(
    'Shutdown waits for pending work and disposes the engine only once',
    () async {
      final gate = Completer<void>();
      final engine = ControlledEngine()..validationGate = gate;
      final controller = ConnectionController(
        engine: engine,
        configPath: 'test.json',
      );
      final operation = controller.validate();
      expect(controller.busy, isTrue);
      final shutdown = controller.shutdown();
      expect(identical(shutdown, controller.shutdown()), isTrue);
      expect(engine.disposalCalls, 0);
      gate.complete();
      await operation;
      await shutdown;
      expect(engine.disposalCalls, 1);
      controller.dispose();
      expect(engine.disposalCalls, 1);
    },
  );
}
