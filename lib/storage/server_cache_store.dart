// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import '../profiles/subscription_loader.dart';
import 'app_paths.dart';
import 'service_settings_document.dart';

/// The active subscription's last downloaded server list. It is shown at the
/// next start right away, before the subscription is downloaded anew.
class ServerCache {
  const ServerCache({required this.url, required this.result});

  final String url;
  final SubscriptionLoadResult result;

  /// Lines instead of one text: saved settings may not hold line breaks.
  Map<String, Object?> toJson() => {
    'version': 1,
    'url': url,
    'lines': const LineSplitter().convert(result.source ?? ''),
    'title': result.title,
    'descriptionLines': result.description == null
        ? null
        : const LineSplitter().convert(result.description!),
    'webPageUrl': result.webPageUrl,
    'supportUrl': result.supportUrl,
    'expiresAt': result.expiresAt?.toUtc().toIso8601String(),
  };

  /// Null when nothing usable was saved.
  static ServerCache? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['version'] != 1) return null;
    final url = json['url'];
    final lines = json['lines'];
    if (url is! String || lines is! List || lines.isEmpty) return null;
    final SubscriptionLoadResult parsed;
    try {
      parsed = parseSubscriptionDetailed(lines.cast<String>().join('\n'));
    } on FormatException {
      return null;
    }
    final description = json['descriptionLines'];
    final expiresAt = json['expiresAt'];
    return ServerCache(
      url: url,
      result: SubscriptionLoadResult(
        profiles: parsed.profiles,
        skippedCount: parsed.skippedCount,
        title: json['title'] as String? ?? parsed.title,
        description: description is List
            ? description.cast<String>().join('\n')
            : parsed.description,
        webPageUrl: json['webPageUrl'] as String? ?? parsed.webPageUrl,
        supportUrl: json['supportUrl'] as String? ?? parsed.supportUrl,
        expiresAt: expiresAt is String
            ? DateTime.tryParse(expiresAt)
            : parsed.expiresAt,
        source: parsed.source,
      ),
    );
  }
}

abstract interface class ServerCacheStore {
  Future<ServerCache?> read();

  /// Saves [cache], or forgets the saved list when it is null.
  Future<void> write(ServerCache? cache);
}

ServerCacheStore createServerCacheStore() =>
    Platform.isWindows ? WindowsServerCacheStore() : FileServerCacheStore();

/// Kept by the Windows service in the app's settings folder, like the other
/// settings.
class WindowsServerCacheStore implements ServerCacheStore {
  WindowsServerCacheStore({ServiceSettingsDocument? document})
    : _document = document ?? ServiceSettingsDocument('servers');
  final ServiceSettingsDocument _document;
  bool _loaded = false;

  @override
  Future<ServerCache?> read() async {
    final cache = await _document.read(ServerCache.fromJson);
    _loaded = true;
    return cache;
  }

  @override
  Future<void> write(ServerCache? cache) async {
    // The service only accepts a write after a read of the same document.
    if (!_loaded) await read();
    try {
      await _document.write(cache?.toJson() ?? const {'version': 1});
    } catch (_) {
      _loaded = false;
      rethrow;
    }
  }
}

class FileServerCacheStore implements ServerCacheStore {
  FileServerCacheStore({this.directory});
  final Directory? directory;

  Future<File> _file() async => File(
    '${directory?.path ?? '${(await AppPaths.root()).path}/settings'}'
    '/server-cache.json',
  );

  @override
  Future<ServerCache?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      return ServerCache.fromJson(json is Map<String, dynamic> ? json : null);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(ServerCache? cache) async {
    final file = await _file();
    if (cache == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(cache.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}
