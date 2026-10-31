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

  static Future<void> start() async {
    try {
      await _run('probe', null);
    } catch (_) {
      await _run('start', null);
    }
  }

  static Future<Map<String, dynamic>> request(
    Map<String, Object?> value,
  ) async {
    final reply = jsonDecode(await _run('request', value));
    if (reply is! Map<String, dynamic>) {
      throw StateError('Invalid Windows service reply.');
    }
    return reply;
  }
}
