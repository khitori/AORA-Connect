// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'app_paths.dart';

import '../core/connection_mode.dart';
import '../core/core_kind.dart';
import '../core/dns_provider.dart';
import '../core/ping_type.dart';
import '../profiles/subscription_loader.dart';
import '../routing/routing_policy.dart';

class SavedSubscription {
  const SavedSubscription(this.url, {this.selectedServerKey});

  final String url;
  final String? selectedServerKey;

  String get label {
    return url.startsWith('https://')
        ? Uri.parse(url).host
        : parseSubscription(url).first.name;
  }

  SavedSubscription withSelectedServer(String? key) =>
      SavedSubscription(url, selectedServerKey: key);

  Map<String, Object?> toJson() => {
    'url': url,
    'selectedServerKey': selectedServerKey,
  };
}

class AppSettingsData {
  const AppSettingsData({
    this.subscriptions = const [],
    this.activeSubscriptionUrl,
    this.mode = ConnectionMode.tun,
    this.core = CoreKind.singBox,
    this.dnsProvider = DnsProvider.cloudflare,
    this.killSwitchEnabled = true,
    this.statisticsEnabled = false,
    this.pingType = PingType.proxyGet,
    this.routingPolicy = const RoutingPolicy(),
  });

  final List<SavedSubscription> subscriptions;
  final String? activeSubscriptionUrl;
  final ConnectionMode mode;
  final CoreKind core;
  final DnsProvider dnsProvider;
  final bool killSwitchEnabled;
  final bool statisticsEnabled;
  final PingType pingType;
  final RoutingPolicy routingPolicy;

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported saved app data version.');
    }
    final entries = <SavedSubscription>[];
    final seen = <String>{};
    for (final item in (json['subscriptions'] as List? ?? const [])) {
      if (item is! Map || item['url'] is! String) continue;
      final url = (item['url'] as String).trim();
      final uri = Uri.tryParse(url);
      if (uri == null || !seen.add(url)) {
        continue;
      }
      if (uri.scheme == 'https') {
        if (uri.host.isEmpty || uri.userInfo.isNotEmpty) continue;
      } else {
        try {
          parseSubscription(url);
        } on FormatException {
          continue;
        }
      }
      entries.add(
        SavedSubscription(
          url,
          selectedServerKey: item['selectedServerKey'] is String
              ? item['selectedServerKey'] as String
              : null,
        ),
      );
    }
    final active = json['activeSubscriptionUrl'];
    final mode = ConnectionMode.values.where(
      (value) => value.name == json['mode'],
    );
    final core = CoreKind.values.where((value) => value.name == json['core']);
    return AppSettingsData(
      subscriptions: entries,
      activeSubscriptionUrl: active is String && seen.contains(active)
          ? active
          : null,
      mode: mode.isEmpty ? ConnectionMode.tun : mode.first,
      core: core.isEmpty ? CoreKind.singBox : core.first,
      dnsProvider: DnsProvider.values.firstWhere(
        (value) => value.name == json['dnsProvider'],
        orElse: () => DnsProvider.cloudflare,
      ),
      pingType: PingType.values.firstWhere(
        (value) => value.name == json['pingType'],
        orElse: () => PingType.proxyGet,
      ),
      // The old persistent Kill Switch was forcibly disabled during recovery.
      // Start the new connection-scoped protection with its own saved setting.
      killSwitchEnabled: json['connectionLeakProtectionEnabled'] is bool
          ? json['connectionLeakProtectionEnabled'] as bool
          : true,
      statisticsEnabled: json['statisticsEnabled'] is bool
          ? json['statisticsEnabled'] as bool
          : false,
      routingPolicy: json['routingPolicy'] is Map
          ? RoutingPolicy.fromJson(
              Map<String, dynamic>.from(json['routingPolicy'] as Map),
            )
          : const RoutingPolicy(),
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'subscriptions': subscriptions.map((entry) => entry.toJson()).toList(),
    'activeSubscriptionUrl': activeSubscriptionUrl,
    'mode': mode.name,
    'core': core.name,
    'dnsProvider': dnsProvider.name,
    'connectionLeakProtectionEnabled': killSwitchEnabled,
    'statisticsEnabled': statisticsEnabled,
    'pingType': pingType.name,
    'routingPolicy': routingPolicy.toJson(),
  };
}

abstract interface class AppSettingsStore {
  Future<AppSettingsData> read();
  Future<void> write(AppSettingsData data);
}

class FileAppSettingsStore implements AppSettingsStore {
  FileAppSettingsStore({this.directory, this.legacyDirectory});

  final Directory? directory;
  final Directory? legacyDirectory;

  Future<Directory> _directory() async {
    if (directory != null) return directory!;
    return Directory('${(await AppPaths.root()).path}/settings');
  }

  Future<File?> _legacyFile() async {
    if (legacyDirectory != null) {
      return File('${legacyDirectory!.path}/app-state.json');
    }
    if (directory != null) return null;
    if (Platform.isWindows) {
      final base = Platform.environment['APPDATA'];
      return base == null ? null : File('$base/AORAVPN/app-state.json');
    }
    if (Platform.isAndroid) {
      return File('${(await AppPaths.root()).path}/app-state.json');
    }
    if (Platform.isLinux) {
      final root = await AppPaths.root();
      return File('${root.parent.path}/aoravpn/app-state.json');
    }
    return null;
  }

  Future<File> _file() async {
    final location = await _directory();
    return File('${location.path}${Platform.pathSeparator}app-state.json');
  }

  @override
  Future<AppSettingsData> read() async {
    final file = await _file();
    if (!await file.exists()) {
      final legacy = await _legacyFile();
      if (legacy == null || !await legacy.exists()) {
        return const AppSettingsData();
      }
      final json = jsonDecode(await legacy.readAsString());
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Saved app data is invalid.');
      }
      final data = AppSettingsData.fromJson(json);
      await write(data);
      // Remove only this validated legacy file after verifying its replacement.
      if (await file.readAsString() == jsonEncode(data.toJson())) {
        await legacy.delete();
      }
      return data;
    }
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) throw const FormatException();
      return AppSettingsData.fromJson(json);
    } on FormatException {
      throw const FormatException('Saved app data is invalid.');
    }
  }

  @override
  Future<void> write(AppSettingsData data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    if (Platform.isLinux) await _chmod('700', file.parent.path);
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
    if (Platform.isLinux) await _chmod('600', file.path);
  }

  Future<void> _chmod(String mode, String path) async {
    final result = await Process.run('chmod', [mode, '--', path]);
    if (result.exitCode != 0) {
      throw FileSystemException('Could not secure saved app data.', path);
    }
  }
}
