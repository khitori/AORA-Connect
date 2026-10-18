// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/connection_probe.dart';

void main() {
  test(
    'Connection check returns elapsed time after a successful request',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) => request.response.close());
      final elapsed = await probeConnection(
        port: null,
        targetUrl: Uri.parse('http://127.0.0.1:${server.port}/'),
      );
      expect(elapsed, isA<Duration>());
    },
  );

  test('Connection check preserves socket failure and failing stage', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    await expectLater(
      probeConnection(
        port: null,
        targetUrl: Uri.parse('http://127.0.0.1:$port/'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'details',
          allOf(
            contains('DNS lookup / connection'),
            contains('SocketException'),
          ),
        ),
      ),
    );
  });
}
