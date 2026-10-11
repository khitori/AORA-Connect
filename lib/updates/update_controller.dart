// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/app_paths.dart';

typedef UpdateVerifier = Future<Map<String, dynamic>> Function(
  String command,
  String path,
);

class AppRelease {
  AppRelease(Map<String, dynamic> json)
    : version = json['version'] as String,
      size = json['size'] as int,
      sha256 = json['sha256'] as String,
      urls = (json['urls'] as List).cast<String>(),
      notes = json['notes'] as String;
  final String version, sha256, notes;
  final int size;
  final List<String> urls;
}

List<int> releaseVersion(String value) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$').firstMatch(value);
  if (match == null) {
    throw const FormatException('Invalid application version.');
  }
  return [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
}

bool newerRelease(String candidate, String current) {
  final a = releaseVersion(candidate), b = releaseVersion(current);
  for (var i = 0; i < 4; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

Uri updateUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException(
      'Update sources must be HTTPS URLs without credentials.',
    );
  }
  return uri;
}

class UpdateController extends ChangeNotifier {
  UpdateController({
    this.verifier,
    this.preferencesDirectory,
    this.sessionCreator,
    String? helperPath,
  }) : helperPath =
           helperPath ??
           '${File(Platform.resolvedExecutable).parent.path}/aoravpn_update.exe';
  static const githubSource =
      'https://github.com/khitori/AORA-Connect/releases/latest/download/aora-update.json';
  final UpdateVerifier? verifier;
  final Directory? preferencesDirectory;
  final Future<Directory> Function()? sessionCreator;
  final String helperPath;
  String currentVersion = '';
  String get displayVersion =>
      currentVersion.isEmpty ? 'Loading…' : currentVersion.split('+').first;
  bool automaticChecks = true, busy = false, installing = false;
  List<String> additionalSources = [];
  AppRelease? release;
  File? package;
  String? error;
  String status = 'Check for updates';
  double? progress;
  bool _disposed = false;
  HttpClient? _client;
  final _sessions = <Directory>[];
  bool get supported => Platform.isWindows;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<File> _preferences() async {
    final directory =
        preferencesDirectory ??
        Directory('${(await AppPaths.root()).path}/settings');
    await directory.create(recursive: true);
    return File('${directory.path}/updates.json');
  }

  Future<Directory> _session() async {
    final directory =
        await (sessionCreator?.call() ?? AppPaths.createSession('update-'));
    _sessions.add(directory);
    return directory;
  }

  Future<Map<String, dynamic>> _verify(String command, String path) async {
    if (verifier != null) return verifier!(command, path);
    if (!await File(helperPath).exists()) {
      throw StateError('Restart the rebuilt application to enable updates.');
    }
    final result = await Process.run(helperPath, [
      command,
      if (path.isNotEmpty) path,
    ]).timeout(const Duration(seconds: 30));
    if (result.exitCode != 0) throw StateError('${result.stderr}'.trim());
    return jsonDecode('${result.stdout}') as Map<String, dynamic>;
  }

  Future<void> initialize({bool checkAutomatically = true}) async {
    if (!supported) return;
    try {
      currentVersion = (await _verify('info', ''))['version'] as String;
      final file = await _preferences();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map;
        automaticChecks = json['automaticChecks'] != false;
        additionalSources = [
          for (final source in json['sources'] as List? ?? [])
            updateUrl(source as String).toString(),
        ];
      }
      _changed();
      if (automaticChecks && checkAutomatically && !_disposed) await check();
    } catch (e) {
      error = '$e';
      _changed();
    }
  }

  Future<void> setPreferences({bool? automatic, List<String>? sources}) async {
    final parsed = sources == null
        ? additionalSources
        : [for (final source in sources) updateUrl(source.trim()).toString()];
    final value = automatic ?? automaticChecks;
    final file = await _preferences();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'automaticChecks': value, 'sources': parsed}),
      flush: true,
    );
    await temporary.rename(file.path);
    automaticChecks = value;
    additionalSources = parsed;
    _changed();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    progress = null;
    _changed();
    try {
      await action();
    } catch (e) {
      error = '$e';
      status = 'Update could not be completed';
    } finally {
      _client?.close(force: true);
      _client = null;
      busy = false;
      _changed();
    }
  }

  Future<HttpClientResponse> _get(Uri uri) async {
    _client ??= HttpClient()..connectionTimeout = const Duration(seconds: 15);
    for (var attempt = 0; attempt < 6; attempt++) {
      if (_disposed) throw StateError('Update cancelled.');
      final request = await _client!
          .getUrl(updateUrl(uri.toString()))
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) throw StateError('Invalid update redirect.');
        uri = updateUrl(uri.resolve(location).toString());
        _client!.close(force: true);
        _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'Update request failed (HTTP ${response.statusCode}).',
        );
      }
      return response;
    }
    throw StateError('Too many update redirects.');
  }

  Future<void> check() => _perform(() async {
    status = 'Checking for updates…';
    _changed();
    Object? failure;
    for (final source in [githubSource, ...additionalSources]) {
      try {
        final response = await _get(updateUrl(source));
        final bytes = <int>[];
        await for (final chunk in response.timeout(
          const Duration(seconds: 15),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 65536) {
            throw StateError('Update metadata exceeds its size limit.');
          }
        }
        final directory = await _session();
        final metadata = File('${directory.path}/aora-update.json');
        await metadata.writeAsBytes(bytes, flush: true);
        final candidate = AppRelease(
          await _verify('verify-manifest', metadata.path),
        );
        release = newerRelease(candidate.version, currentVersion)
            ? candidate
            : null;
        package = null;
        status = release == null
            ? 'No newer update found'
            : 'Update ${release!.version.split('+').first} available';
        return;
      } catch (e) {
        failure = e;
        _client?.close(force: true);
        _client = null;
      }
    }
    throw StateError(
      'Could not check updates. You can install a downloaded update file.\n$failure',
    );
  });
  Future<void> download() => _perform(() async {
    final expected = release;
    if (expected == null) return;
    final directory = await _session();
    final file = File('${directory.path}/AORAConnect-Setup.exe');
    Object? failure;
    for (final url in {
      ...expected.urls,
      for (final source in additionalSources)
        updateUrl(source).resolve('AORAConnect-Setup.exe').toString(),
    }) {
      try {
        status = 'Downloading update…';
        _changed();
        final response = await _get(updateUrl(url));
        final sink = file.openWrite();
        var received = 0;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 20),
          )) {
            received += chunk.length;
            if (received > expected.size + 65560) {
              throw StateError(
                'Update download exceeds its signed size limit.',
              );
            }
            sink.add(chunk);
            progress = (received / (expected.size + 65560)).clamp(0, 1);
            _changed();
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        final actual = AppRelease(await _verify('verify-package', file.path));
        if (actual.version != expected.version ||
            actual.sha256 != expected.sha256) {
          throw StateError(
            'Downloaded file does not match the selected release.',
          );
        }
        await _stageHelper(directory);
        package = file;
        status = 'Update verified and ready to install';
        progress = 1;
        return;
      } catch (e) {
        failure = e;
        _client?.close(force: true);
        _client = null;
      }
    }
    throw StateError('Could not download a verified update.\n$failure');
  });
  Future<void> importFile(String path) => _perform(() async {
    status = 'Verifying update file…';
    _changed();
    final source = File(path);
    if (await source.length() > 512 * 1024 * 1024 + 65560) {
      throw StateError('Update file is too large.');
    }
    final directory = await _session();
    final file = await source.copy('${directory.path}/AORAConnect-Setup.exe');
    final candidate = AppRelease(await _verify('verify-package', file.path));
    if (!newerRelease(candidate.version, currentVersion)) {
      throw StateError('Choose an update newer than $currentVersion.');
    }
    await _stageHelper(directory);
    release = candidate;
    package = file;
    status =
        'Update ${candidate.version.split('+').first} verified and ready to install';
  });
  Future<void> _stageHelper(Directory directory) async {
    await File(helperPath).copy('${directory.path}/aoravpn_update.exe');
  }

  Future<void> install({
    required bool Function() canInstall,
    required Future<void> Function(String path) launch,
  }) async {
    if (busy || installing || package == null) return;
    if (!canInstall()) {
      error = 'Disconnect before installing an update.';
      _changed();
      return;
    }
    installing = true;
    _changed();
    try {
      final candidate = AppRelease(
        await _verify('verify-package', package!.path),
      );
      if (!newerRelease(candidate.version, currentVersion)) {
        throw StateError(
          'This update is not newer than the installed application.',
        );
      }
      if (!canInstall()) {
        throw StateError('Disconnect before installing an update.');
      }
      await launch(package!.path);
    } catch (e) {
      error = '$e';
      installing = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _client?.close(force: true);
    if (!installing) {
      for (final directory in _sessions) {
        unawaited(
          directory.delete(recursive: true).catchError((_) => directory),
        );
      }
    }
    super.dispose();
  }
}
