// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

Future<Duration> probeConnection({int? port = 17890}) async {
  final client = HttpClient();
  client.findProxy = (_) => port == null ? 'DIRECT' : 'PROXY 127.0.0.1:$port';
  client.connectionTimeout = const Duration(seconds: 15);
  final watch = Stopwatch()..start();
  try {
    final request = await client
        .getUrl(Uri.parse('https://example.com/'))
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Connection test failed (HTTP ${response.statusCode}).');
    }
    await response.drain<void>().timeout(const Duration(seconds: 15));
    return watch.elapsed;
  } on IOException {
    throw StateError(
      'Proxy connection failed. Check the server and core logs.',
    );
  } finally {
    client.close(force: true);
  }
}
