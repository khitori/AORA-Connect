// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/connection_button.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/controllers/node_ping_controller.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/unavailable_tunnel_engine.dart';
import 'package:aoravpn/pages/connection_page.dart';
import 'package:aoravpn/theme/app_theme.dart';

ConnectionController _preview() => ConnectionController(
  engine: const UnavailableTunnelEngine(),
  xrayEngine: const UnavailableTunnelEngine(),
  configPath: 'unused-preview.json',
);

void main() {
  test(
    'Unavailable backends cannot report a working VPN for either core',
    () async {
      final connection = _preview();
      final pings = NodePingController(connection);
      addTearDown(() async {
        await pings.shutdown();
        pings.dispose();
        await connection.shutdown();
        connection.dispose();
      });
      expect(connection.supported, isFalse);
      expect(connection.canConnect, isFalse);
      expect(connection.killSwitchAvailable, isFalse);
      expect(pings.canCheck, isFalse);
      for (final core in CoreKind.values) {
        await connection.setCore(core);
        await connection.connect();
        expect(connection.state, TunnelState.stopped);
        expect(connection.error, contains(UnavailableTunnelEngine.reason));
      }
    },
  );

  testWidgets(
    'Unavailable engine disables Connect without development labels',
    (tester) async {
      tester.view.physicalSize = const Size(393, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final connection = _preview();
      final pings = NodePingController(connection);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await pings.shutdown();
        pings.dispose();
        await connection.shutdown();
        connection.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ConnectionPage(connection: connection, pings: pings),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Android preview'), findsNothing);
      expect(
        tester
            .widget<ConnectionButton>(find.byType(ConnectionButton))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
