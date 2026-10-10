// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/core/ping_type.dart';
import 'package:aoravpn/storage/app_settings_store.dart';

void main() {
  test('DNS defaults safely for old or unknown settings and round-trips', () {
    expect(const AppSettingsData().dnsProvider, DnsProvider.cloudflare);
    for (final value in [null, 'unknown', 123]) {
      expect(
        AppSettingsData.fromJson({'version': 1, 'dnsProvider': value})
            .dnsProvider,
        DnsProvider.cloudflare,
      );
    }
    for (final provider in DnsProvider.values) {
      expect(
        AppSettingsData.fromJson(
          AppSettingsData(dnsProvider: provider).toJson(),
        ).dnsProvider,
        provider,
      );
    }
  });
  test(
    'Migrates legacy state without overwriting existing new settings',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'aora-migration-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final legacy = Directory('${root.path}/legacy');
      await legacy.create();
      final oldStore = FileAppSettingsStore(directory: legacy);
      await oldStore.write(const AppSettingsData(core: CoreKind.xray));
      final destination = Directory('${root.path}/settings');
      final store = FileAppSettingsStore(
        directory: destination,
        legacyDirectory: legacy,
      );
      expect((await store.read()).core, CoreKind.xray);
      expect(await File('${destination.path}/app-state.json').exists(), isTrue);
      expect(await File('${legacy.path}/app-state.json').exists(), isFalse);
      await oldStore.write(const AppSettingsData(core: CoreKind.singBox));
      expect((await store.read()).core, CoreKind.xray);
      expect(await File('${legacy.path}/app-state.json').exists(), isTrue);
    },
  );

  test('Invalid legacy state is preserved and not migrated', () async {
    final root = await Directory.systemTemp.createTemp('aora-migration-test-');
    addTearDown(() => root.delete(recursive: true));
    final legacy = Directory('${root.path}/legacy');
    await legacy.create();
    final oldFile = File('${legacy.path}/app-state.json');
    await oldFile.writeAsString('{invalid');
    final destination = Directory('${root.path}/settings');
    final store = FileAppSettingsStore(
      directory: destination,
      legacyDirectory: legacy,
    );
    await expectLater(store.read(), throwsFormatException);
    expect(await oldFile.exists(), isTrue);
    expect(await File('${destination.path}/app-state.json').exists(), isFalse);
  });
  test('Writes settings to disk and restores them', () async {
    final directory = await Directory.systemTemp.createTemp(
      'aoravpn-state-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileAppSettingsStore(directory: directory);
    const url = 'https://provider.example/sub/private-token';
    await store.write(
      const AppSettingsData(
        subscriptions: [SavedSubscription(url, selectedServerKey: 'server-2')],
        activeSubscriptionUrl: url,
        mode: ConnectionMode.proxy,
        core: CoreKind.xray,
        dnsProvider: DnsProvider.quad9,
        pingType: PingType.proxyHead,
      ),
    );

    final restored = await store.read();
    expect(restored.subscriptions.single.url, url);
    expect(restored.subscriptions.single.selectedServerKey, 'server-2');
    expect(restored.activeSubscriptionUrl, url);
    expect(restored.mode, ConnectionMode.proxy);
    expect(restored.core, CoreKind.xray);
    expect(restored.dnsProvider, DnsProvider.quad9);
    expect(restored.pingType, PingType.proxyHead);
    expect(restored.killSwitchEnabled, isTrue);
  });

  test('Restores direct server links as saved sources', () {
    const link = 'trojan://secret@node.example:443#Trojan';
    final restored = AppSettingsData.fromJson({
      'version': 1,
      'subscriptions': [
        {'url': link},
      ],
      'activeSubscriptionUrl': link,
      'mode': 'tun',
    });
    expect(restored.subscriptions.single.label, 'Trojan');
    expect(restored.activeSubscriptionUrl, link);
    expect(restored.core, CoreKind.singBox);
    expect(restored.pingType, PingType.proxyGet);
    expect(restored.killSwitchEnabled, isTrue);
  });

  test('Persists explicitly disabled connection leak protection', () {
    const data = AppSettingsData(killSwitchEnabled: false);
    final restored = AppSettingsData.fromJson(data.toJson());
    expect(restored.killSwitchEnabled, isFalse);
  });

  test('Old forced-OFF Kill Switch does not disable new leak protection', () {
    final restored = AppSettingsData.fromJson({
      'version': 1,
      'killSwitchEnabled': false,
    });
    expect(restored.killSwitchEnabled, isTrue);
  });

  test('Statistics defaults to OFF and saves an explicit ON choice', () {
    expect(AppSettingsData.fromJson({'version': 1}).statisticsEnabled, isFalse);
    const data = AppSettingsData(statisticsEnabled: true);
    expect(AppSettingsData.fromJson(data.toJson()).statisticsEnabled, isTrue);
  });
}
