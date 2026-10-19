// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/connection_probe.dart';

void main() {
  test(
    'Stalled TLS setup reports the connection stage instead of a raw timeout',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      server.listen(sockets.add);
      addTearDown(() async {
        for (final socket in sockets) {
          socket.destroy();
        }
        await server.close();
      });
      await expectLater(
        probeConnection(
          port: null,
          targetUrl: Uri.parse('https://127.0.0.1:${server.port}/'),
          connectionTimeout: const Duration(milliseconds: 150),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'stage',
            allOf(
              contains('DNS lookup / connection'),
              contains('timed out'),
              isNot(contains('Future not completed')),
            ),
          ),
        ),
      );
    },
  );

  test('Missing response headers identify the HTTPS request stage', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {});
    addTearDown(() => server.close(force: true));
    await expectLater(
      probeConnection(
        port: null,
        targetUrl: Uri.parse('http://127.0.0.1:${server.port}/'),
        requestTimeout: const Duration(milliseconds: 150),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'stage',
          allOf(contains('HTTPS request'), contains('timed out')),
        ),
      ),
    );
  });

  test('Stalled response bodies identify the body stage', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = 10;
      request.response.write('x');
      await request.response.flush();
    });
    addTearDown(() => server.close(force: true));
    await expectLater(
      probeConnection(
        port: null,
        targetUrl: Uri.parse('http://127.0.0.1:${server.port}/'),
        bodyTimeout: const Duration(milliseconds: 150),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'stage',
          allOf(contains('response body'), contains('timed out')),
        ),
      ),
    );
  });

  test(
    'Successful verification logs all stages without URLs or credentials',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) => request.response.close());
      addTearDown(() => server.close(force: true));
      final stages = <String>[];
      await probeConnection(
        port: null,
        targetUrl: Uri.parse('http://127.0.0.1:${server.port}/private-token'),
        onStage: stages.add,
      );
      expect(stages, hasLength(3));
      expect(stages[0], contains('DNS lookup / connection'));
      expect(stages[1], contains('HTTPS request'));
      expect(stages[2], contains('response body'));
      expect(stages.join(), isNot(contains('private-token')));
    },
  );

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
