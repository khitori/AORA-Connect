// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/connection_plan.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/windows_service_engine.dart';
import 'package:aoravpn/core/windows_service_transport.dart';
import 'package:aoravpn/core/windows_check_client.dart';
import 'package:aoravpn/core/ping_cancellation.dart';
import 'package:aoravpn/l10n/locale_controller.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/routing/routing_policy.dart';
import 'package:aoravpn/storage/app_paths.dart';
import 'package:aoravpn/storage/app_settings_store.dart';
import 'package:aoravpn/storage/platform_settings_stores.dart';

class _ReadOnlySettings implements AppSettingsStore {
  _ReadOnlySettings(this.data);
  final AppSettingsData data;
  @override
  Future<AppSettingsData> read() async => data;
  @override
  Future<void> write(AppSettingsData data) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled =
      Platform.isWindows &&
      Platform.environment['AORA_TEST_INSTALLED_SERVICE'] == '1';

  test(
    'Installed service accepts complete generated profiles without starting a VPN',
    () async {
      final client = WindowsServiceClient();
      try {
        final initial = await client.refresh();
        expect(initial.state, TunnelState.stopped);
        expect(initial.issued, initial.completed);
        final links = [
          'hy2://secret@127.0.0.1:443?sni=example.com',
          'trojan://secret@127.0.0.1:443?sni=example.com',
          'ss://aes-128-gcm:secret@127.0.0.1:8388',
          'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=ws&sni=example.com&path=%2Fvpn',
          'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=httpupgrade&sni=example.com&path=%2Fvpn',
          'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&serviceName=vpn&pcs=${'ab' * 32}',
          'vmess://${base64.encode(utf8.encode(jsonEncode({'v': '2', 'add': '127.0.0.1', 'port': '443', 'id': 'bf000d23-0752-40b4-affe-68f7707a9661', 'aid': '0', 'scy': 'auto', 'net': 'tcp', 'tls': ''})))}',
        ];
        for (final link in links) {
          final profile = parseSubscription(link).single;
          final engine = WindowsServiceEngine(client, profile.coreKind);
          try {
            for (final mode in ConnectionMode.values) {
              for (final dns in DnsProvider.values) {
                for (final routed in [false, true]) {
                  final plan = ConnectionPlan(
                    profile: profile,
                    serverAddress: '127.0.0.1',
                    mode: mode,
                    dnsProvider: dns,
                    leakProtection: true,
                    routing: RoutingPolicy(
                      enabled: routed,
                      rules: const [
                        RoutingRule(
                          match: RoutingMatch.domain,
                          target: 'example.org',
                        ),
                      ],
                    ),
                  );
                  await engine.validatePlan(plan);
                  expect(client.current?.state, TunnelState.stopped);
                  expect(client.current?.session, isNull);
                }
              }
            }
          } finally {
            await engine.dispose();
          }
        }
      } finally {
        await client.dispose();
      }
    },
    skip:
        !enabled &&
        !(Platform.isWindows &&
            Platform.environment['AORA_TEST_CONNECTION_PLANS'] == '1'),
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Installed preferences restore through the real service without provider access or rewrites',
    () async {
      final file = File('${AppPaths.windowsRoot.path}/settings/app-state.json');
      expect(await file.exists(), isTrue);
      final before = await file.readAsBytes();
      final saved = await createAppSettingsStore().read();
      final languageFile = File(
        '${AppPaths.windowsRoot.path}/settings/language.json',
      );
      final language = jsonDecode(await languageFile.readAsString()) as Map;
      expect(
        await createLanguageStore().read() == language['language'],
        isTrue,
      );
      final controller = ConnectionController(
        settingsStore: _ReadOnlySettings(saved),
        subscriptionLoader: (_) async => SubscriptionLoadResult(
          profiles: parseSubscription(
            saved.core == CoreKind.xray
                ? 'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&serviceName=vpn&pcs=${'ab' * 32}'
                : 'hy2://secret@127.0.0.1:443?sni=example.com',
          ),
        ),
      );
      try {
        await controller.restore();
        expect(
          controller.error == null,
          isTrue,
          reason:
              'Full restoration of the installed settings/subscription failed.',
        );
        expect(controller.subscriptions.length, saved.subscriptions.length);
        expect(
          controller.activeSubscriptionUrl == saved.activeSubscriptionUrl,
          isTrue,
        );
        expect(controller.mode == saved.mode, isTrue);
        expect(controller.activeCore == saved.core, isTrue);
        expect(controller.dnsProvider == saved.dnsProvider, isTrue);
        expect(controller.pingType == saved.pingType, isTrue);
        expect(controller.statisticsEnabled == saved.statisticsEnabled, isTrue);
        expect(controller.killSwitchEnabled == saved.killSwitchEnabled, isTrue);
        expect(
          jsonEncode(controller.routingPolicy.toJson()) ==
              jsonEncode(saved.routingPolicy.toJson()),
          isTrue,
        );
        if (saved.activeSubscriptionUrl != null) {
          expect(controller.profiles.isNotEmpty, isTrue);
          expect(controller.selected != null, isTrue);
        }
        expect(controller.state, TunnelState.stopped);
      } finally {
        await controller.shutdown();
        controller.dispose();
        expect(
          base64Encode(await file.readAsBytes()) == base64Encode(before),
          isTrue,
          reason: 'The integration check must not rewrite installed settings.',
        );
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Ordinary enrolled account reads installed preferences through the service',
    () async {
      final access = await WindowsServiceTransport.request({
        'protocol': 1,
        'command': 'access',
      });
      expect(access['ok'], isTrue);
      final rights = access['access'] as Map;
      expect(rights['owner'], isTrue);
      expect(rights['privileged'], isFalse);
      expect(rights['settings'], isTrue);
      expect(rights['runtime'], isTrue);
      Future<Map<String, dynamic>> read(String document) =>
          WindowsServiceTransport.request({
            'protocol': 1,
            'command': 'settings.read',
            'document': document,
          });
      final appBefore = await read('app');
      final languageBefore = await read('language');
      final updatesBefore = await read('updates');
      expect(appBefore['ok'], isTrue);
      expect(languageBefore['ok'], isTrue);
      expect(updatesBefore['ok'], isTrue);
      final app = await createAppSettingsStore().read();
      final rawSubscriptions =
          (appBefore['value'] as Map?)?['subscriptions'] as List?;
      expect(
        app.subscriptions.length == (rawSubscriptions?.length ?? 0),
        isTrue,
      );
      final locale = LocaleController(store: createLanguageStore());
      try {
        await locale.initialize();
        expect(locale.restoreFailed, isFalse);
        expect(
          locale.language == (languageBefore['value'] as Map?)?['language'],
          isTrue,
        );
      } finally {
        locale.dispose();
      }
      await createUpdatePreferencesStore().read();
      for (final entry in {
        'app': appBefore,
        'language': languageBefore,
        'updates': updatesBefore,
      }.entries) {
        final after = await read(entry.key);
        expect(after['ok'], isTrue);
        expect(after['revision'] == entry.value['revision'], isTrue);
      }
      final denied = await WindowsServiceTransport.request({
        'protocol': 1,
        'command': 'status',
        'cursor': 0,
      });
      expect(denied['ok'], isFalse);
      expect(denied['error'], 'access_denied');
    },
    skip:
        !Platform.isWindows ||
        Platform.environment['AORA_TEST_SERVICE_SETTINGS'] != '1',
  );
  test(
    'Ordinary account prepares mixed-core server checks without client runtime files',
    () async {
      final access = await WindowsServiceTransport.request({
        'protocol': 1,
        'command': 'access',
      });
      expect((access['access'] as Map)['privileged'], isFalse);
      final vpn = WindowsServiceClient();
      WindowsCheckSession? session;
      try {
        final before = await vpn.refresh();
        expect(before.state, TunnelState.stopped);
        final nodes = <Map<String, Object?>>[];
        for (var i = 0; i < 70; i++) {
          final profile = parseSubscription(
            i.isEven
                ? 'hy2://dummy@127.0.0.1:443?sni=example.com'
                : 'vless://bf000d23-0752-40b4-affe-68f7707a9661@127.0.0.1:443?security=tls&type=grpc&serviceName=vpn&pcs=${'ab' * 32}',
          ).single;
          nodes.add({
            'index': i,
            'core': profile.coreKind.name,
            'outbound': profile.outbound(serverAddress: '127.0.0.1'),
          });
        }
        nodes.add({
          'index': 70,
          'core': 'singBox',
          'outbound': {'type': 'direct', 'tag': 'proxy'},
        });
        nodes.add({
          'index': 71,
          'core': 'xray',
          'outbound': {'protocol': 'freedom', 'tag': 'proxy'},
        });
        session = await WindowsCheckClient().open(nodes, PingCancellation());
        expect(session.ports.length, 70);
        expect(session.errors.keys.toSet(), {70, 71});
        final ports = [session.ports[0]!, session.ports[1]!];
        for (final port in ports) {
          final socket = await Socket.connect(
            '127.0.0.1',
            port,
            timeout: const Duration(seconds: 1),
          );
          socket.destroy();
        }
        await session.dispose();
        final after = await vpn.refresh();
        expect(after.state, TunnelState.stopped);
        expect(after.issued, before.issued);
        expect(after.completed, before.completed);
        for (final port in ports) {
          await expectLater(
            Socket.connect(
              '127.0.0.1',
              port,
              timeout: const Duration(seconds: 1),
            ),
            throwsA(isA<SocketException>()),
          );
        }
      } finally {
        await session?.dispose();
        await vpn.dispose();
      }
    },
    skip:
        !Platform.isWindows ||
        Platform.environment['AORA_TEST_SERVICE_CHECKS'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
