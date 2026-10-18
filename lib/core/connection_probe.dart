// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

Future<Duration> probeConnection({int? port = 17890, Uri? targetUrl}) async {
  final client = HttpClient();
  client.findProxy = (_) => port == null ? 'DIRECT' : 'PROXY 127.0.0.1:$port';
  client.connectionTimeout = const Duration(seconds: 15);
  final watch = Stopwatch()..start();
  var stage = 'DNS lookup / connection';
  try {
    final request = await client
        .getUrl(targetUrl ?? Uri.parse('https://example.com/'))
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    stage = 'HTTPS request';
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Connection test failed (HTTP ${response.statusCode}).');
    }
    stage = 'response body';
    await response.drain<void>().timeout(const Duration(seconds: 15));
    return watch.elapsed;
  } on IOException catch (error) {
    throw StateError('Connection check failed during $stage: $error');
  } finally {
    client.close(force: true);
  }
}
