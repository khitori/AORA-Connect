// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/installed_application_picker.dart';
import 'package:aoravpn/components/app_expansion_card.dart';
import 'package:aoravpn/components/routing_rule_card.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/core/unavailable_tunnel_engine.dart';
import 'package:aoravpn/pages/routing_page.dart';
import 'package:aoravpn/routing/routing_policy.dart';
import 'package:aoravpn/theme/app_theme.dart';

void main() {
  Future<ConnectionController> controller(WidgetTester tester) async {
    final connection = ConnectionController(
      engine: const UnavailableTunnelEngine(),
      xrayEngine: const UnavailableTunnelEngine(),
    );
    await connection.setRoutingPolicy(
      const RoutingPolicy(
        rules: [
          RoutingRule(
            match: RoutingMatch.application,
            target: 'com.microsoft.emmx',
          ),
        ],
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await connection.shutdown();
      connection.dispose();
    });
    return connection;
  }

  testWidgets('Routing section, Add rule and first rule use equal gaps', (
    tester,
  ) async {
    final connection = await controller(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RoutingPage(
            connection: connection,
            applicationLoader: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final section = tester.getRect(find.byType(AppExpansionCard));
    final button = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Add rule'),
    );
    final card = tester.getRect(find.byType(RoutingRuleCard));
    expect(button.top - section.bottom, closeTo(16, 0.01));
    expect(card.top - button.bottom, closeTo(16, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Saved application rules display name and icon without changing the package target',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final connection = await controller(tester);
      final icon = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j5xkAAAAASUVORK5CYII=',
      );
      var loads = 0;
      Future<List<InstalledApplication>> load() async {
        loads++;
        return [
          InstalledApplication(
            packageName: 'com.microsoft.emmx',
            label: 'Microsoft Edge',
            icon: icon,
          ),
        ];
      }

      Widget page() => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RoutingPage(connection: connection, applicationLoader: load),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Microsoft Edge'), findsOneWidget);
      expect(find.text('com.microsoft.emmx'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(
        connection.routingPolicy.rules.single.target,
        'com.microsoft.emmx',
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unavailable metadata keeps the saved rule readable and usable', (
    tester,
  ) async {
    final connection = await controller(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutingPage(
            connection: connection,
            applicationLoader: () async =>
                throw StateError('Package unavailable'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('com.microsoft.emmx'), findsOneWidget);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    expect(connection.routingPolicy.rules.single.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
