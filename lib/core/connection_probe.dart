// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

Future<Duration> probeConnection({
  int? port = 17890,
  Uri? targetUrl,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration requestTimeout = const Duration(seconds: 20),
  Duration bodyTimeout = const Duration(seconds: 15),
  void Function(String)? onStage,
}) async {
  final client = HttpClient();
  client.findProxy = (_) => port == null ? 'DIRECT' : 'PROXY 127.0.0.1:$port';
  client.connectionTimeout = connectionTimeout;
  final watch = Stopwatch()..start();
  var stage = 'DNS lookup / connection';
  try {
    onStage?.call('Connection check: $stage (including TLS).');
    final request = await client
        .getUrl(targetUrl ?? Uri.parse('https://example.com/'))
        .timeout(connectionTimeout);
    request.followRedirects = false;
    stage = 'HTTPS request';
    onStage?.call('Connection check: $stage.');
    final response = await request.close().timeout(requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'Connection check failed during $stage (HTTP ${response.statusCode}).',
      );
    }
    stage = 'response body';
    onStage?.call('Connection check: $stage.');
    await response.drain<void>().timeout(bodyTimeout);
    return watch.elapsed;
  } on TimeoutException catch (error) {
    throw StateError(
      'Connection check timed out during $stage '
      'after ${error.duration?.inMilliseconds ?? watch.elapsedMilliseconds} ms.',
    );
  } on IOException catch (error) {
    throw StateError('Connection check failed during $stage: $error');
  } finally {
    client.close(force: true);
  }
}
