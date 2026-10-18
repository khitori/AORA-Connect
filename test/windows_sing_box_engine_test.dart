// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/windows_core_engine.dart';

void main() {
  test('Xray proxy starts, accepts HTTP, and stops', () async {
    final xray = File('cores/windows/xray-v26.9.30-windows-64/xray.exe');
    if (!Platform.isWindows || !xray.existsSync()) return;
    final temp = await Directory.systemTemp.createTemp('aoravpn-xray-run-');
    final reserved = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reserved.port;
    await reserved.close();
    final config = File('${temp.path}/config.json');
    await config.writeAsString(
      jsonEncode({
        'log': {'loglevel': 'warning'},
        'inbounds': [
          {'listen': '127.0.0.1', 'port': port, 'protocol': 'http'},
        ],
        'outbounds': [
          {'protocol': 'freedom'},
        ],
      }),
    );
    final engine = WindowsXrayEngine(
      executablePath: xray.absolute.path,
      hostPath: 'missing-host.exe',
    );
    try {
      await engine.start(config.path);
      expect(engine.state, TunnelState.running);
      final socket = await Socket.connect('127.0.0.1', port);
      socket.destroy();
      await engine.stop();
      expect(engine.state, TunnelState.stopped);
    } finally {
      await engine.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('Windows core host launches and gracefully stops Xray', () async {
    final xray = File('cores/windows/xray-v26.9.30-windows-64/xray.exe');
    final host = File('build/windows/x64/runner/Debug/aoravpn_core_host.exe');
    if (!Platform.isWindows || !xray.existsSync() || !host.existsSync()) return;
    final temp = await Directory.systemTemp.createTemp('aoravpn-xray-host-');
    final reserved = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reserved.port;
    await reserved.close();
    final config = File('${temp.path}/config.json');
    await config.writeAsString(
      jsonEncode({
        'log': {'loglevel': 'warning'},
        'inbounds': [
          {'listen': '127.0.0.1', 'port': port, 'protocol': 'http'},
        ],
        'outbounds': [
          {'protocol': 'freedom'},
        ],
      }),
    );
    final engine = WindowsXrayEngine(
      executablePath: xray.absolute.path,
      hostPath: host.absolute.path,
    );
    try {
      for (var attempt = 0; attempt < 10; attempt++) {
        await engine.start(config.path);
        expect(engine.state, TunnelState.running);
        final socket = await Socket.connect('127.0.0.1', port);
        socket.destroy();
        final shutdown = engine.logs.firstWhere(
          (line) => line.startsWith('Core stopped (exit'),
        );
        await engine.stop();
        expect(engine.state, TunnelState.stopped);
        expect(
          await shutdown.timeout(const Duration(seconds: 2)),
          'Core stopped (exit 0).',
        );
      }
    } finally {
      await engine.dispose();
      await temp.delete(recursive: true);
    }
  });
  final executable = File(
    'cores/windows/sing-box-1.14.2-windows-amd64/sing-box.exe',
  ).absolute.path;
  final available = Platform.isWindows && File(executable).existsSync();

  test(
    'Real core validates, starts, serves SOCKS, stops and restarts',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'aoravpn-core-test-',
      );
      final host = File('build/windows/x64/runner/Debug/aoravpn_core_host.exe');
      final engine = WindowsSingBoxEngine(
        executablePath: executable,
        hostPath: host.existsSync() ? host.absolute.path : null,
      );
      final logs = <String>[];
      final subscription = engine.logs.listen(logs.add);
      final reserved = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = reserved.port;
      await reserved.close();
      final config = File('${temporary.path}/config.json');
      await config.writeAsString(
        jsonEncode({
          'log': {'level': 'info'},
          'inbounds': [
            {'type': 'mixed', 'listen': '127.0.0.1', 'listen_port': port},
          ],
          'outbounds': [
            {'type': 'direct'},
          ],
        }),
      );
      try {
        await engine.validate(config.path);
        await engine.start(config.path);
        expect(engine.state, TunnelState.running);
        final socket = await Socket.connect('127.0.0.1', port);
        socket.add([5, 1, 0]);
        await socket.flush();
        final reply = await socket.first.timeout(const Duration(seconds: 5));
        expect(reply.take(2), [5, 0]);
        socket.destroy();
        final shutdown = host.existsSync()
            ? engine.logs.firstWhere(
                (line) => line.startsWith('Core stopped (exit'),
              )
            : null;
        await engine.stop();
        expect(engine.state, TunnelState.stopped);
        if (shutdown != null) {
          expect(
            await shutdown.timeout(const Duration(seconds: 2)),
            'Core stopped (exit 0).',
          );
        }
        await engine.start(config.path);
        await engine.stop();
        expect(logs.any((line) => line.contains('sing-box started')), isTrue);

        final occupied = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        try {
          await expectLater(
            engine.start(config.path),
            throwsA(
              isA<StateError>().having(
                (error) => error.message.toString(),
                'actual startup error',
                allOf(contains('listen tcp'), contains('127.0.0.1:$port')),
              ),
            ),
          );
          expect(engine.state, TunnelState.stopped);
        } finally {
          await occupied.close();
        }

        await config.writeAsString('invalid json');
        await expectLater(engine.start(config.path), throwsStateError);
        expect(engine.state, TunnelState.stopped);
      } finally {
        await engine.dispose();
        await subscription.cancel();
        await temporary.delete(recursive: true);
      }
    },
    skip: available ? false : 'Windows sing-box binary is required.',
  );

  test(
    'Missing executable is reported and leaves the engine stopped',
    () async {
      final engine = WindowsSingBoxEngine(executablePath: 'missing-core.exe');
      try {
        await expectLater(engine.start('missing.json'), throwsStateError);
        expect(engine.state, TunnelState.stopped);
      } finally {
        await engine.dispose();
      }
    },
    skip: Platform.isWindows ? false : 'Windows only.',
  );
}
