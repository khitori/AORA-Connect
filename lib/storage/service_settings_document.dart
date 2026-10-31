// SPDX-License-Identifier: GPL-3.0-or-later
import '../core/windows_service_transport.dart';

typedef SettingsRequest = Future<Map<String, dynamic>> Function(
  Map<String, Object?> request,
);

class ServiceSettingsDocument {
  ServiceSettingsDocument(
    this.document, {
    SettingsRequest? request,
    Future<void> Function()? ensureStarted,
  }) : _request = request ?? WindowsServiceTransport.request,
       _start =
           ensureStarted ??
           (request == null ? WindowsServiceTransport.start : () async {});
  final String document;
  final SettingsRequest _request;
  final Future<void> Function() _start;
  String? _revision;
  Future<void> _tail = Future.value();
  bool _started = false;
  void invalidate() {
    _revision = null;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<Map<String, dynamic>> _send(
    String command, [
    Map<String, Object?> fields = const {},
  ]) async {
    if (!_started) {
      await _start();
      _started = true;
    }
    final reply = await _request({
      'protocol': 1,
      'command': command,
      'document': document,
      ...fields,
    });
    if (reply['protocol'] != 1 || reply['ok'] != true) {
      final error = reply['error'];
      if (error == 'settings_conflict') {
        throw StateError(
          'Settings changed in another session. Reload them before saving.',
        );
      }
      if (error == 'invalid_stored_settings') {
        throw StateError(
          'Saved settings could not be read. The original file was kept.',
        );
      }
      throw StateError(
        'Settings service is unavailable or rejected the request.',
      );
    }
    final revision = reply['revision'];
    if (revision is! String ||
        !RegExp(r'^(missing|[0-9a-f]{64})$').hasMatch(revision)) {
      throw StateError('Invalid settings revision.');
    }
    return reply;
  }

  Future<T> read<T>(T Function(Map<String, dynamic>? value) decode) =>
      _serialized(() async {
        _revision = null;
        try {
          final reply = await _send('settings.read');
          final value = reply['value'];
          if (value != null && value is! Map<String, dynamic>) {
            throw const FormatException('Invalid saved settings.');
          }
          final result = decode(value as Map<String, dynamic>?);
          _revision = reply['revision'] as String;
          return result;
        } catch (_) {
          _started = false;
          rethrow;
        }
      });

  Future<void> write(Map<String, Object?> value, {String? expectedRevision}) =>
      _serialized(() async {
        final revision = _revision;
        if (revision == null) {
          throw StateError(
            'Load saved settings successfully before changing them.',
          );
        }
        if (expectedRevision != null && revision != expectedRevision) {
          throw StateError('Settings changed before migration could finish.');
        }
        try {
          final reply = await _send('settings.write', {
            'revision': revision,
            'value': value,
          });
          _revision = reply['revision'] as String;
        } catch (_) {
          _revision = null;
          _started = false;
          rethrow;
        }
      });
}
