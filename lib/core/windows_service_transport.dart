// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../storage/app_paths.dart';

class WindowsServiceTransport {
  static const maxFrame = 512 * 1024;
  static Future<String> _read(Stream<List<int>> stream, int limit) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > limit) {
        throw StateError('Windows service output exceeded its size limit.');
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  static Future<String> _run(
    String command,
    Map<String, Object?>? request,
  ) async {
    final helper = AppPaths.windowsHelper('aoravpn_service');
    if (!await File(helper).exists()) {
      throw StateError(
        'The Windows service helper is missing. Repair the installation.',
      );
    }
    final body = request == null ? null : utf8.encode(jsonEncode(request));
    if (body != null && body.length > maxFrame) {
      throw StateError('The Windows service request is too large.');
    }
    final process = await Process.start(helper, [command]);
    final output = _read(process.stdout, maxFrame + 4);
    final errors = _read(process.stderr, 8192);
    final completion = Future.wait<Object>([
      process.exitCode,
      output,
      errors,
    ], eagerError: true);
    completion.ignore();
    try {
      if (body != null) process.stdin.add(body);
      await process.stdin.close().timeout(const Duration(seconds: 12));
      final result = await completion.timeout(
        Duration(seconds: command == 'start' ? 25 : 12),
      );
      if (result[0] != 0) {
        throw StateError(
          'Windows service $command failed: ${(result[2] as String).trim()}',
        );
      }
      return result[1] as String;
    } catch (_) {
      process.kill();
      await process.exitCode;
      await completion.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      rethrow;
    }
  }

  /// The last check that the service runs. At app start settings, the
  /// connection, checks and startup each make sure of it within a moment, so
  /// a check is shared for [_shareFor]: one helper launch instead of one per
  /// part. Later actions check again, in case the service was stopped
  /// meanwhile; a failed check or request is forgotten at once.
  static Future<void>? _started;
  static DateTime? _startedAt;
  static const _shareFor = Duration(seconds: 10);

  static Future<void> start() {
    final at = _startedAt;
    if (_started != null &&
        (at == null || DateTime.now().difference(at) < _shareFor)) {
      return _started!;
    }
    _startedAt = null;
    return _started = _start().then(
      (_) => _startedAt = DateTime.now(),
      onError: (Object error, StackTrace stack) {
        _started = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  static Future<void> _start() async {
    try {
      await _run('probe', null);
    } catch (_) {
      await _run('start', null);
    }
  }

  /// One helper kept running for all requests, instead of launching one per
  /// request. Null until the first request or after it ended.
  static HelperSession? _session;

  /// Set when the installed helper is older and has no session mode; then
  /// every request launches its own helper, as before.
  static bool _sessionUnsupported = false;

  static Future<Map<String, dynamic>> request(
    Map<String, Object?> value,
  ) async {
    final String output;
    try {
      output = await _send(value);
    } catch (_) {
      _started = null;
      _startedAt = null;
      rethrow;
    }
    final reply = jsonDecode(output);
    if (reply is! Map<String, dynamic>) {
      throw StateError('Invalid Windows service reply.');
    }
    return reply;
  }

  static Future<String> _send(Map<String, Object?> value) async {
    if (_sessionUnsupported) return _run('request', value);
    final body = jsonEncode(value);
    if (utf8.encode(body).length > maxFrame) {
      throw StateError('The Windows service request is too large.');
    }
    var session = _session;
    if (session == null || !session.alive) {
      final helper = AppPaths.windowsHelper('aoravpn_service');
      if (!await File(helper).exists()) {
        throw StateError(
          'The Windows service helper is missing. Repair the installation.',
        );
      }
      session = _session = await HelperSession.open(helper);
    }
    try {
      return await session.send(body);
    } on HelperSessionUnsupported {
      _sessionUnsupported = true;
      _session = null;
      return _run('request', value);
    }
  }
}

/// The installed helper ended its session mode without answering anything,
/// as an older helper that does not know it does.
class HelperSessionUnsupported implements Exception {
  const HelperSessionUnsupported();
}

/// A helper running in session mode: one request per line on its input,
/// each answered on its own line, in order. It ends when its input closes,
/// so it also ends with the app.
class HelperSession {
  HelperSession._(this._process) {
    // Requests are UTF-8 text, as the helper reads them; not the Windows
    // code page the input would use otherwise.
    _process.stdin.encoding = utf8;
    // A write to a helper that already ended is reported by [send] instead.
    _process.stdin.done.ignore();
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            _answered = true;
            if (_pending.isNotEmpty) _pending.removeAt(0).complete(line);
          },
          onDone: _ended,
          onError: (Object _) => _ended(),
        );
    _process.stderr.drain<void>().ignore();
    _process.exitCode.then((_) => _ended()).ignore();
  }

  static Future<HelperSession> open(
    String helper, {
    List<String> arguments = const ['session'],
  }) async => HelperSession._(await Process.start(helper, arguments));

  static const _timeout = Duration(seconds: 12);

  final Process _process;
  final _pending = <Completer<String>>[];
  bool _alive = true;
  bool _answered = false;

  bool get alive => _alive;

  Future<String> send(String body) async {
    if (!_alive) throw StateError('Windows service helper ended.');
    final reply = Completer<String>();
    _pending.add(reply);
    _process.stdin.writeln(body);
    try {
      return await reply.future.timeout(_timeout);
    } on TimeoutException {
      // A stuck helper would hold up every later request: replace it.
      close();
      throw StateError('Windows service request timed out.');
    }
  }

  void close() {
    if (!_alive) return;
    _process.kill();
    _ended();
  }

  void _ended() {
    if (!_alive && _pending.isEmpty) return;
    _alive = false;
    final error = _answered
        ? StateError('Windows service helper ended.')
        : const HelperSessionUnsupported();
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
  }
}
