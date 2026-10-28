// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

Future<Duration> probeConnection({
  int? port = 17890,
  Uri? targetUrl,
  List<Uri>? targetUrls,
  Duration connectionTimeout = const Duration(seconds: 15),
  Duration requestTimeout = const Duration(seconds: 20),
  Duration bodyTimeout = const Duration(seconds: 15),
  void Function(String)? onStage,
}) async {
  if (targetUrl != null && targetUrls != null) {
    throw ArgumentError('Specify targetUrl or targetUrls, not both.');
  }
  final targets =
      targetUrls ??
      (targetUrl == null
          ? [
              Uri.parse('https://www.gstatic.com/generate_204'),
              Uri.parse('https://cp.cloudflare.com/generate_204'),
            ]
          : [targetUrl]);
  if (targets.isEmpty) {
    throw ArgumentError('At least one test URL is required.');
  }
  for (var index = 0; index < targets.length; index++) {
    if (index > 0) {
      onStage?.call('Connection check: trying another HTTPS test endpoint.');
    }
    try {
      return await _probeEndpoint(
        port: port,
        targetUrl: targets[index],
        connectionTimeout: connectionTimeout,
        requestTimeout: requestTimeout,
        bodyTimeout: bodyTimeout,
        onStage: onStage,
      );
    } on StateError catch (error) {
      onStage?.call('Connection check endpoint ${index + 1} failed: $error');
      if (index == targets.length - 1) rethrow;
    }
  }
  throw StateError('No connection check endpoint succeeded.');
}

Future<Duration> _probeEndpoint({
  required int? port,
  required Uri targetUrl,
  required Duration connectionTimeout,
  required Duration requestTimeout,
  required Duration bodyTimeout,
  void Function(String)? onStage,
}) async {
  final client = HttpClient();
  client.findProxy = (_) => port == null ? 'DIRECT' : 'PROXY 127.0.0.1:$port';
  client.connectionTimeout = connectionTimeout;
  final watch = Stopwatch()..start();
  var stage = 'DNS lookup / connection';
  try {
    onStage?.call('Connection check: $stage (including TLS).');
    final request = await client.getUrl(targetUrl).timeout(connectionTimeout);
    request.followRedirects = false;
    stage = 'HTTPS request';
    onStage?.call('Connection check: $stage.');
    final response = await request.close().timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
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
  } on HandshakeException catch (error) {
    throw StateError(
      'Connection check failed during TLS handshake / certificate verification: $error',
    );
  } on IOException catch (error) {
    throw StateError('Connection check failed during $stage: $error');
  } finally {
    client.close(force: true);
  }
}
