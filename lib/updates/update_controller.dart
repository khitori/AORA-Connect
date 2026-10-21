// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../l10n/app_localizations_en.dart';
import '../l10n/app_localizations.dart';
import '../l10n/directional_text.dart';
import '../l10n/localized_exception.dart';
import '../storage/app_paths.dart';
import 'android_updates.dart';
import 'update_cache.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  verifying,
  imported,
  failed,
  installed,
}

enum UpdatePlatform { windows, android, unsupported }

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
    throw LocalizedFormatException((strings) => strings.httpsSourcesOnly);
  }
  return uri;
}

class UpdateController extends ChangeNotifier {
  UpdateController({
    this.verifier,
    this.preferencesDirectory,
    this.sessionCreator,
    this.runtimeDirectory,
    UpdatePlatform? platform,
    String? helperPath,
  }) : platform =
           platform ??
           (Platform.isAndroid
               ? UpdatePlatform.android
               : Platform.isWindows
               ? UpdatePlatform.windows
               : UpdatePlatform.unsupported),
       helperPath =
           helperPath ??
           '${File(Platform.resolvedExecutable).parent.path}/aoravpn_update.exe';
  static const githubSource =
      'https://github.com/khitori/AORA-Connect/releases/latest/download/aora-update.json';
  static const androidGithubSource =
      'https://github.com/khitori/AORA-Connect/releases/latest/download/aora-update-android.json';
  final UpdatePlatform platform;
  bool get isAndroid => platform == UpdatePlatform.android;
  String get packageName =>
      isAndroid ? 'AORAConnect.apk' : 'AORAConnect-Setup.exe';
  String get defaultSource => isAndroid ? androidGithubSource : githubSource;
  final UpdateVerifier? verifier;
  final Directory? preferencesDirectory;
  final Future<Directory> Function()? sessionCreator;
  final Directory? runtimeDirectory;
  final String helperPath;
  String currentVersion = '';
  String get displayVersion =>
      currentVersion.isEmpty ? 'Loading…' : currentVersion.split('+').first;
  bool automaticChecks = true, busy = false, installing = false;
  List<String> additionalSources = [];
  AppRelease? release;
  File? package;
  String? error;
  UpdatePhase _phase = UpdatePhase.idle;
  String get status => localizedStatus(AppLocalizationsEn());
  String localizedStatus(AppLocalizations l10n) => switch (_phase) {
    UpdatePhase.idle => l10n.checkUpdates,
    UpdatePhase.checking => l10n.checkingUpdates,
    UpdatePhase.upToDate => l10n.upToDate,
    UpdatePhase.available => l10n.updateAvailable(
      isolateTechnicalValue(l10n, release!.version.split('+').first),
    ),
    UpdatePhase.downloading => l10n.downloadingUpdate,
    UpdatePhase.ready => l10n.updateReady,
    UpdatePhase.verifying => l10n.verifyingUpdate,
    UpdatePhase.imported => l10n.updateVersionReady(
      isolateTechnicalValue(l10n, release!.version.split('+').first),
    ),
    UpdatePhase.failed => l10n.updateFailed,
    UpdatePhase.installed => l10n.installationCompleted,
  };
  double? progress;
  bool _disposed = false;
  HttpClient? _client;
  final _sessions = <Directory, RandomAccessFile>{};
  Timer? _cleanupRetry;
  UpdateCache? _cache;
  bool get supported => platform != UpdatePlatform.unsupported;

  bool _newer(String version) => isAndroid
      ? releaseVersion(version).last > releaseVersion(currentVersion).last
      : newerRelease(version, currentVersion);

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
    final lock = await UpdateCache.acquire(directory);
    if (lock == null) throw StateError('Update storage is in use.');
    _sessions[directory] = lock;
    return directory;
  }

  Future<void> _cleanup({bool recover = false}) async {
    try {
      final pending = await _cache?.sweep(
        currentVersion,
        preferredPackage: package?.path,
      );
      if (recover && pending != null && !_disposed) {
        await _stageHelper(pending.file.parent);
        package = pending.file;
        release = AppRelease(pending.release);
        _phase = UpdatePhase.ready;
      }
      if (isAndroid && verifier == null) await AndroidUpdates.cleanup();
    } catch (_) {
      // Cleanup is best effort: file locks/permissions must not block updates.
    }
  }

  Future<void> _releaseSessions() async {
    final sessions = Map<Directory, RandomAccessFile>.of(_sessions);
    _sessions.clear();
    for (final entry in sessions.entries) {
      final ready = entry.key.uri == package?.parent.uri;
      try {
        if (!ready) {
          final cache = UpdateCache(
            entry.key.parent,
            packageName: packageName,
            inspect: (path) => _verify('inspect-package', path),
            newer: newerRelease,
          );
          await cache.discardLocked(entry.key);
        }
      } on FileSystemException {
        // A locked file is retried by the next startup sweep.
      } finally {
        await UpdateCache.release(entry.key, entry.value);
        if (!ready) await UpdateCache.removeEmptySession(entry.key);
      }
    }
  }

  Future<Map<String, dynamic>> _verify(String command, String path) async {
    if (verifier != null) return verifier!(command, path);
    if (isAndroid) return AndroidUpdates.verify(command, path);
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
      // Injected test/custom storage must never scan the real application's data.
      final runtime =
          runtimeDirectory ??
          (preferencesDirectory == null && sessionCreator == null
              ? Directory('${(await AppPaths.root()).path}/runtime')
              : null);
      if (runtime != null) {
        _cache = UpdateCache(
          runtime,
          packageName: packageName,
          inspect: (path) => _verify('inspect-package', path),
          newer: (a, b) => isAndroid
              ? releaseVersion(a).last > releaseVersion(b).last
              : newerRelease(a, b),
        );
        await _cleanup(recover: true);
        // An installer/helper may still be exiting during the first sweep.
        _cleanupRetry = Timer(const Duration(seconds: 30), () async {
          if (!_disposed && !busy && !installing) await _cleanup();
        });
      }
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
      if (automaticChecks &&
          checkAutomatically &&
          !_disposed &&
          package == null) {
        await check();
      }
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
    if (busy || installing || _disposed) return;
    busy = true;
    error = null;
    progress = null;
    _changed();
    try {
      await action();
    } catch (e) {
      error = '$e';
      _phase = UpdatePhase.failed;
    } finally {
      _client?.close(force: true);
      _client = null;
      await _releaseSessions();
      await _cleanup();
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
    _phase = UpdatePhase.checking;
    _changed();
    Object? failure;
    for (final source in [defaultSource, ...additionalSources]) {
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
        // A metadata check must not discard a verified package awaiting retry.
        if (package == null) {
          release = _newer(candidate.version) ? candidate : null;
        }
        _phase = release == null
            ? UpdatePhase.upToDate
            : package != null
            ? UpdatePhase.ready
            : UpdatePhase.available;
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
    package = null;
    final directory = await _session();
    final file = File('${directory.path}/$packageName');
    final sizeLimit = expected.size + (isAndroid ? 0 : 65560);
    Object? failure;
    for (final url in {
      ...expected.urls,
      for (final source in additionalSources)
        updateUrl(source).resolve(packageName).toString(),
    }) {
      try {
        _phase = UpdatePhase.downloading;
        _changed();
        final response = await _get(updateUrl(url));
        final sink = file.openWrite();
        var received = 0;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 20),
          )) {
            received += chunk.length;
            if (received > sizeLimit) {
              throw StateError(
                'Update download exceeds its signed size limit.',
              );
            }
            sink.add(chunk);
            progress = (received / sizeLimit).clamp(0, 1);
            _changed();
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (isAndroid && received != expected.size) {
          throw StateError('APK download is incomplete.');
        }
        final actual = AppRelease(await _verify('verify-package', file.path));
        if (actual.version != expected.version ||
            actual.sha256 != expected.sha256 ||
            actual.size != expected.size) {
          throw StateError(
            'Downloaded file does not match the selected release.',
          );
        }
        await _stageHelper(directory);
        package = file;
        _phase = UpdatePhase.ready;
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
    package = null;
    _phase = UpdatePhase.verifying;
    _changed();
    final source = File(path);
    if (await source.length() > 512 * 1024 * 1024 + 65560) {
      throw StateError('Update file is too large.');
    }
    final directory = await _session();
    final file = await source.copy('${directory.path}/$packageName');
    final candidate = AppRelease(await _verify('verify-package', file.path));
    if (!_newer(candidate.version)) {
      throw StateError('Choose an update newer than $currentVersion.');
    }
    await _stageHelper(directory);
    release = candidate;
    package = file;
    _phase = UpdatePhase.imported;
  });
  Future<void> _stageHelper(Directory directory) async {
    if (isAndroid) return;
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
    RandomAccessFile? lease;
    var marked = false;
    final directory = package!.parent;
    try {
      lease = await UpdateCache.acquire(directory);
      if (lease == null) throw StateError('Update storage is in use.');
      final candidate = AppRelease(
        await _verify('verify-package', package!.path),
      );
      if (!_newer(candidate.version)) {
        throw StateError(
          'This update is not newer than the installed application.',
        );
      }
      if (release == null ||
          candidate.version != release!.version ||
          candidate.sha256 != release!.sha256 ||
          candidate.size != release!.size) {
        throw StateError(
          'Update file changed after verification. Import or download it again.',
        );
      }
      if (!canInstall()) {
        throw StateError('Disconnect before installing an update.');
      }
      await File(
        '${package!.parent.path}/installing.json',
      ).writeAsString(jsonEncode({'version': candidate.version}), flush: true);
      marked = true;
      await launch(package!.path);
      if (isAndroid) {
        await File('${package!.parent.path}/installing.json').delete();
        installing = false;
        _phase = UpdatePhase.installed;
        _changed();
      }
    } catch (e) {
      if (marked) {
        try {
          await File('${package!.parent.path}/installing.json').delete();
        } catch (_) {}
      }
      error = '$e';
      installing = false;
      _changed();
    } finally {
      if (lease != null) await UpdateCache.release(directory, lease);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cleanupRetry?.cancel();
    _client?.close(force: true);
    // In-flight work owns its leases until its finally block. Verified pending
    // files survive exit for retry; startup sweeps all obsolete versions.
    super.dispose();
  }
}
