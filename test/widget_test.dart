// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/controllers/node_ping_controller.dart';
import 'package:aoravpn/app.dart';
import 'package:aoravpn/components/app_select.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/pages/subscriptions_page.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/profiles/xray_vless_profile.dart';
import 'package:aoravpn/routing/routing_policy.dart';

class FakeEngine implements TunnelEngine {
  final changes = StreamController<TunnelState>.broadcast();
  final messages = StreamController<String>.broadcast();
  @override
  TunnelState state = TunnelState.stopped;
  @override
  Stream<TunnelState> get states => changes.stream;
  @override
  Stream<String> get logs => messages.stream;
  @override
  Future<void> validate(String configPath) async {}
  @override
  Future<void> start(String configPath) async {
    state = TunnelState.running;
    changes.add(state);
    messages.add('Test core started');
  }

  @override
  Future<void> stop() async {
    state = TunnelState.stopped;
    changes.add(state);
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Routing tab adds and edits a rule on compact navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine));
    await tester.tap(find.byKey(const ValueKey('bottom-nav-routing')));
    await tester.pumpAndSettle();
    expect(
      find.text('Route listed applications and addresses'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    await tester.tap(find.byType(AppSelect<RoutingAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Through tunnel'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Listed items go through the tunnel. Everything else uses your normal connection.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(AppSelect<RoutingAction>));
    await tester.pumpAndSettle();
    expect(find.text('Through tunnel'), findsWidgets);
    expect(find.text('Bypassing tunnel'), findsOneWidget);
    expect(find.text('Block'), findsNothing);
    await tester.tap(find.text('Bypassing tunnel'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Listed items use your normal connection. Everything else goes through the tunnel.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Add rule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'chrome.exe');
    expect(find.text('Choose running application'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(AppSelect<RoutingAction>),
      ),
      findsNothing,
    );
    expect(find.text('Block'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('chrome.exe'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit rule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'firefox.exe');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('firefox.exe'), findsOneWidget);
    expect(find.text('chrome.exe'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });

  testWidgets('Statistics and Diagnostics expand on compact desktop layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine));
    expect(find.text('Statistics'), findsNothing);
    await _openSettings(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Statistics'), 200);
    await Scrollable.ensureVisible(
      tester.element(find.text('Statistics')),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    final titleRect = tester.getRect(find.text('Statistics'));
    final statusRect = tester.getRect(find.text('Off'));
    expect(statusRect.top - titleRect.bottom, lessThanOrEqualTo(4));
    expect(
      tester.getCenter(find.byKey(const ValueKey('statistics-toggle'))).dy,
      closeTo((titleRect.top + statusRect.bottom) / 2, 1),
    );
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(find.text('Statistics is off.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('statistics-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Ping once'), findsNothing);
    expect(find.text('Connect to collect live ICMP samples.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Diagnostics'), 200);
    await Scrollable.ensureVisible(
      tester.element(find.text('Diagnostics')),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Core logs'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });

  testWidgets('Large subscription builds only visible node rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    final input = TextEditingController();
    final controller = ConnectionController(
      engine: engine,
      subscriptionLoader: (_) async => SubscriptionLoadResult(
        profiles: List.generate(
          500,
          (index) => HysteriaProfile(
            name: 'Server ${index + 1}',
            server: '127.0.0.1',
            port: 443,
            password: 'secret',
            serverName: 'example.com',
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => controller.addSubscription('https://example.com/large'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionsPage(
            connection: controller,
            pings: NodePingController(controller),
            subscriptionUrl: input,
          ),
        ),
      ),
    );
    expect(find.text('Server 1'), findsOneWidget);
    expect(find.text('Server 500'), findsNothing);
    expect(find.byType(ListTile).evaluate().length, lessThan(50));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Server 500'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(controller.shutdown);
    controller.dispose();
    input.dispose();
    await engine.changes.close();
    await engine.messages.close();
  });

  testWidgets('Subscriptions shows each node required core', (tester) async {
    tester.view.physicalSize = const Size(420, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    final xrayEngine = FakeEngine();
    final input = TextEditingController();
    final controller = ConnectionController(
      engine: engine,
      xrayEngine: xrayEngine,
      subscriptionLoader: (_) async => SubscriptionLoadResult(
        profiles: [
          HysteriaProfile(
            name: 'Sweden 1',
            server: '127.0.0.1',
            port: 443,
            password: 'secret',
            serverName: 'example.com',
          ),
          XrayVlessProfile(
            name: 'Pinned 1',
            server: '127.0.0.1',
            port: 443,
            uuid: 'bf000d23-0752-40b4-affe-68f7707a9661',
            serverName: 'example.com',
            pinnedPeerCertSha256: 'ab' * 32,
            serviceName: 'vpn',
          ),
        ],
      ),
    );
    await tester.runAsync(
      () => controller.addSubscription('https://example.com/sub'),
    );
    await tester.runAsync(
      () => controller.addSubscription('https://second.example.com/sub'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionsPage(
            connection: controller,
            pings: NodePingController(controller),
            subscriptionUrl: input,
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-subscription-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'draft-link');
    await tester.tap(find.byKey(const ValueKey('add-subscription-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(input.text, 'draft-link');
    expect(find.text('sing-box'), findsOneWidget);
    expect(find.text('Xray'), findsOneWidget);
    final savedSelect = find.byKey(const ValueKey('saved-subscription-select'));
    expect(savedSelect, findsOneWidget);
    expect(
      tester.widget<AppSelect<String>>(savedSelect).value,
      'https://second.example.com/sub',
    );
    await tester.tap(savedSelect);
    await tester.pumpAndSettle();
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('second.example.com'), findsNWidgets(2));
    await tester.tap(find.text('second.example.com').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await controller.selectProfile(controller.profiles[1]);
    });
    await tester.pump();
    expect(controller.selectedRequiresDifferentCore, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(controller.shutdown);
    controller.dispose();
    input.dispose();
    await engine.changes.close();
    await engine.messages.close();
    await xrayEngine.changes.close();
    await xrayEngine.messages.close();
  });
  testWidgets(
    'Connect stays visible without a subscription and prompts before starting',
    (tester) async {
      tester.view.physicalSize = const Size(420, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = FakeEngine();
      await tester.pumpWidget(MyApp(engine: engine));
      expect(find.text('Connect'), findsOneWidget);
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(
        find.text('Load a subscription on the Subscriptions tab first.'),
        findsOneWidget,
      );
      expect(engine.state, TunnelState.stopped);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await engine.changes.close();
      await engine.messages.close();
    },
  );

  testWidgets('Bottom navigation and top menu preserve page input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine, configPath: 'test.json'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-subscriptions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-subscription-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.test/sub/demo',
    );
    expect(find.byType(AppSelect<ConnectionMode>), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-settings')), findsNothing);
    await _openSettings(tester);
    await tester.pumpAndSettle();
    expect(find.text('Connection mode'), findsOneWidget);
    expect(find.text('Networking core'), findsOneWidget);
    expect(find.text('Core'), findsOneWidget);
    await tester.tap(find.text('Core'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSelect<CoreKind>), findsNothing);
    await tester.tap(find.text('Core'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSelect<CoreKind>>(find.byType(AppSelect<CoreKind>))
          .value,
      CoreKind.singBox,
    );
    await tester.tap(find.byType(AppSelect<CoreKind>));
    await tester.pumpAndSettle();
    expect(find.text('sing-box 1.14.2'), findsWidgets);
    await tester.tap(find.text('Xray 26.9.30').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSelect<CoreKind>>(find.byType(AppSelect<CoreKind>))
          .value,
      CoreKind.xray,
    );
    final selector = tester.widget<AppSelect<ConnectionMode>>(
      find.byType(AppSelect<ConnectionMode>),
    );
    expect(selector.value, ConnectionMode.tun);
    await tester.tap(find.byType(AppSelect<ConnectionMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local proxy').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-connection')));
    await tester.pumpAndSettle();
    expect(find.text('Local proxy'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-subscriptions')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'https://example.test/sub/demo',
    );
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });

  testWidgets('Subscription errors appear only on Subscriptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine));
    await tester.tap(find.byKey(const ValueKey('bottom-nav-subscriptions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-subscription-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-a-link');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(
      find.text('FormatException: Enter a valid HTTPS subscription URL.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('bottom-nav-connection')));
    await tester.pumpAndSettle();
    expect(find.textContaining('FormatException'), findsNothing);
    await _openSettings(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('FormatException'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-subscriptions')));
    await tester.pumpAndSettle();
    expect(
      find.text('FormatException: Enter a valid HTTPS subscription URL.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });

  testWidgets('Controls reflect the core lifecycle and display logs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine, configPath: 'test.json'));
    expect(tester.takeException(), isNull);
    expect(find.text('sing-box 1.14.2: stopped'), findsOneWidget);
    expect(find.text('VPN (TUN)'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('sing-box 1.14.2: running'), findsOneWidget);
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Test core started'), findsOneWidget);
    await _openSettings(tester);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSelect<ConnectionMode>>(
            find.byType(AppSelect<ConnectionMode>),
          )
          .onChanged,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.text('License: GNU GPL version 3 or later.'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('License: GNU GPL version 3 or later.'), findsOneWidget);
    expect(engine.state, TunnelState.running);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-connection')));
    await tester.pumpAndSettle();
    expect(find.text('sing-box 1.14.2: running'), findsOneWidget);
    await tester.ensureVisible(find.text('Disconnect'));
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('sing-box 1.14.2: stopped'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });
}
