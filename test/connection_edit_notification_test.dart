// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ui' as ui;

import 'package:aoravpn/components/app_notification.dart';
import 'package:aoravpn/components/connection_edit_notification.dart';
import 'package:aoravpn/components/app_select.dart';
import 'package:aoravpn/components/app_toggle.dart';
import 'package:aoravpn/components/routing_rule_card.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/controllers/node_ping_controller.dart';
import 'package:aoravpn/controllers/statistics_controller.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/pages/routing_page.dart';
import 'package:aoravpn/pages/settings_page.dart';
import 'package:aoravpn/pages/subscriptions_page.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/routing/routing_policy.dart';
import 'package:aoravpn/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Engine implements TunnelEngine {
  final changes = StreamController<TunnelState>.broadcast();
  @override
  TunnelState state = TunnelState.stopped;
  void change(TunnelState value) {
    state = value;
    changes.add(value);
  }

  @override
  Stream<TunnelState> get states => changes.stream;
  @override
  Stream<String> get logs => const Stream.empty();
  @override
  Future<void> validate(String path) async {}
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => changes.close();
}

void main() {
  late _Engine engine;
  late ConnectionController connection;
  late StatisticsController statistics;
  late NodePingController pings;
  late TextEditingController input;
  var loads = 0;

  setUp(() {
    loads = 0;
    engine = _Engine();
    connection = ConnectionController(
      engine: engine,
      xrayEngine: _Engine(),
      subscriptionLoader: (_) async {
        loads++;
        return SubscriptionLoadResult(
          profiles: [
            HysteriaProfile(
              name: 'First server',
              server: '127.0.0.1',
              port: 443,
              password: 'test-only',
              serverName: 'test.invalid',
            ),
            HysteriaProfile(
              name: 'Second server',
              server: '127.0.0.1',
              port: 8443,
              password: 'test-only',
              serverName: 'test.invalid',
            ),
          ],
        );
      },
    );
    statistics = StatisticsController(connection);
    pings = NodePingController(connection);
    input = TextEditingController();
  });
  tearDown(() async {
    pings.dispose();
    statistics.dispose();
    await connection.shutdown();
    connection.dispose();
    input.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> mount(WidgetTester tester, Widget Function() page) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: connection,
            builder: (_, _) => page(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder, String message) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    // The disabled child deliberately doesn't receive the pointer; its notice does.
    await tester.tapAt(tester.getCenter(finder));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppNotification),
        matching: find.text(message),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }

  Finder toggle(String label) => find.byWidgetPredicate(
    (widget) => widget is AppToggle && widget.semanticLabel == label,
  );

  testWidgets('notification wrapper preserves the exact disabled rendering', (
    tester,
  ) async {
    final controls = <String, Widget Function()>{
      'button': () =>
          const OutlinedButton(onPressed: null, child: Text('Disabled action')),
      'toggle': () => const AppToggle(
        value: true,
        onChanged: null,
        semanticLabel: 'Disabled toggle',
      ),
      'selector': () => const AppSelect<int>(
        value: 1,
        items: [DropdownMenuItem(value: 1, child: Text('Disabled selector'))],
        onChanged: null,
      ),
    };
    for (final entry in controls.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: const ValueKey('disabled-reference'),
                    child: SizedBox(
                      width: 180,
                      height: 40,
                      child: entry.value(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  RepaintBoundary(
                    key: const ValueKey('disabled-notice'),
                    child: SizedBox(
                      width: 180,
                      height: 40,
                      child: DisabledControlNotice(
                        disabled: true,
                        onTap: () {},
                        child: entry.value(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final identical = await tester.runAsync(() async {
        final reference = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('disabled-reference')),
        );
        final notice = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('disabled-notice')),
        );
        final originalImage = await reference.toImage();
        final noticeImage = await notice.toImage();
        try {
          final originalPixels = await originalImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final noticePixels = await noticeImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return listEquals(
            originalPixels!.buffer.asUint8List(),
            noticePixels!.buffer.asUint8List(),
          );
        } finally {
          originalImage.dispose();
          noticeImage.dispose();
        }
      });
      expect(
        identical,
        isTrue,
        reason:
            '${entry.key}: notification handling must not change disabled visuals',
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'routing controls remain visually disabled and explain taps while connected',
    (tester) async {
      await connection.setRoutingPolicy(
        const RoutingPolicy(
          rules: [
            RoutingRule(match: RoutingMatch.domain, target: 'one.example'),
            RoutingRule(match: RoutingMatch.domain, target: 'two.example'),
          ],
        ),
      );
      engine.change(TunnelState.running);
      await mount(tester, () => RoutingPage(connection: connection));
      const message = 'Disconnect before editing routing rules.';
      expect(find.text(message), findsNothing);
      final original = connection.routingPolicy.toJson();
      final select = find.byType(AppSelect<RoutingAction>);
      expect(tester.widget<AppSelect<RoutingAction>>(select).onChanged, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Add rule'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.widget<AppToggle>(toggle('Routing')).onChanged, isNull);
      await tap(tester, select, message);
      expect(find.byKey(const ValueKey('app-select-menu')), findsNothing);
      await tap(tester, find.text('Add rule'), message);
      expect(find.byType(AlertDialog), findsNothing);
      await tap(tester, toggle('Routing'), message);
      final firstCard = find.byType(RoutingRuleCard).first;
      expect(
        tester
            .widget<AppToggle>(
              find.descendant(
                of: firstCard,
                matching: toggle('Enable one.example'),
              ),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.descendant(
                of: firstCard,
                matching: find.widgetWithText(TextButton, 'Edit'),
              ),
            )
            .onPressed,
        isNull,
      );
      await tap(
        tester,
        find.descendant(of: firstCard, matching: toggle('Enable one.example')),
        message,
      );
      await tap(
        tester,
        find.descendant(of: firstCard, matching: find.byTooltip('Move down')),
        message,
      );
      await tap(
        tester,
        find.descendant(of: firstCard, matching: find.text('Edit')),
        message,
      );
      await tap(
        tester,
        find.descendant(of: firstCard, matching: find.byTooltip('Delete rule')),
        message,
      );
      expect(connection.routingPolicy.toJson(), original);
      expect(connection.busy, isFalse);
      expect(connection.error, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'settings stay disabled and notify without changing core, mode, DNS or Kill Switch',
    (tester) async {
      engine.change(TunnelState.running);
      await mount(
        tester,
        () => SettingsPage(connection: connection, statistics: statistics),
      );
      expect(
        find.text('Stop the connection before changing core, mode or DNS.'),
        findsNothing,
      );
      await tester.tap(find.text('Core'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppSelect<CoreKind>>(find.byType(AppSelect<CoreKind>))
            .onChanged,
        isNull,
      );
      await tap(
        tester,
        find.byType(AppSelect<CoreKind>),
        'Disconnect before changing the core.',
      );
      await tester.tap(find.text('Core'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connection'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppSelect<ConnectionMode>>(
              find.byType(AppSelect<ConnectionMode>),
            )
            .onChanged,
        isNull,
      );
      expect(tester.widget<AppToggle>(toggle('Kill Switch')).onChanged, isNull);
      await tap(
        tester,
        find.byType(AppSelect<ConnectionMode>),
        'Disconnect before changing connection mode.',
      );
      await tap(
        tester,
        toggle('Kill Switch'),
        'Disconnect before changing Kill Switch.',
      );
      await tester.ensureVisible(find.text('Connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DNS'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppSelect<DnsProvider>>(find.byType(AppSelect<DnsProvider>))
            .onChanged,
        isNull,
      );
      await tap(
        tester,
        find.byType(AppSelect<DnsProvider>),
        'Disconnect before changing DNS.',
      );
      expect(find.byKey(const ValueKey('app-select-menu')), findsNothing);
      expect(connection.core, CoreKind.singBox);
      expect(connection.mode, ConnectionMode.tun);
      expect(connection.dnsProvider, DnsProvider.cloudflare);
      expect(connection.killSwitchEnabled, isTrue);
      expect(connection.error, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'subscription controls notify without loading, deleting or switching',
    (tester) async {
      await tester.runAsync(
        () => connection.addSubscription('https://test.invalid/sub'),
      );
      input.text =
          'https://new.invalid/sub'; // Form already open before connecting.
      var clipboardReads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              clipboardReads++;
              return {'text': 'https://clipboard.invalid/sub'};
            }
            return null;
          });
      engine.change(TunnelState.running);
      await mount(
        tester,
        () => SubscriptionsPage(
          connection: connection,
          pings: pings,
          subscriptionUrl: input,
        ),
      );
      const message = 'Disconnect before changing subscriptions.';
      expect(
        find.text('Stop the connection before changing subscriptions.'),
        findsNothing,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Add'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('paste-subscription')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<AppSelect<String>>(
              find.byKey(const ValueKey('saved-subscription-select')),
            )
            .onChanged,
        isNull,
      );
      await tap(tester, find.byType(TextField), message);
      await tap(tester, find.byTooltip('Paste from clipboard'), message);
      await tap(tester, find.widgetWithText(OutlinedButton, 'Add'), message);
      await tap(
        tester,
        find.byKey(const ValueKey('saved-subscription-select')),
        message,
      );
      await tap(
        tester,
        find.byTooltip('Remove selected subscription'),
        message,
      );
      await tap(
        tester,
        find.byTooltip('Refresh selected subscription'),
        'Disconnect before refreshing your subscription.',
      );
      await tap(
        tester,
        find.text('Second server'),
        'Disconnect before changing servers.',
      );
      expect(loads, 1);
      expect(clipboardReads, 0);
      expect(input.text, 'https://new.invalid/sub');
      expect(connection.subscriptions.length, 1);
      expect(connection.selected!.name, 'First server');
      expect(connection.error, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'adding a subscription while connected does not expand its form',
    (tester) async {
      engine.change(TunnelState.running);
      await mount(
        tester,
        () => SubscriptionsPage(
          connection: connection,
          pings: pings,
          subscriptionUrl: input,
        ),
      );
      await tap(
        tester,
        find.byKey(const ValueKey('add-subscription-toggle')),
        'Disconnect before changing subscriptions.',
      );
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'busy operations use a wait notification and stopped controls work normally',
    (tester) async {
      connection.beginMaintenance();
      await mount(tester, () => RoutingPage(connection: connection));
      await tap(
        tester,
        find.text('Add rule'),
        'Wait for the current operation to finish.',
      );
      connection.cancelMaintenance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add rule'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a dropdown opened before connection cannot apply a stale choice',
    (tester) async {
      await mount(
        tester,
        () => SettingsPage(connection: connection, statistics: statistics),
      );
      await tester.tap(find.text('DNS'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppSelect<DnsProvider>));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-select-menu')), findsOneWidget);
      engine.change(TunnelState.running);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(connection.dnsProvider, DnsProvider.cloudflare);
      expect(find.text('Disconnect before changing DNS.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
