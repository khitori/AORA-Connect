// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:aoravpn/components/connection_button.dart';
import 'package:aoravpn/components/server_selector.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/controllers/node_ping_controller.dart';
import 'package:aoravpn/core/unavailable_tunnel_engine.dart';
import 'package:aoravpn/pages/connection_page.dart';
import 'package:aoravpn/profiles/hysteria_profile.dart';
import 'package:aoravpn/profiles/server_profile.dart';
import 'package:aoravpn/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deliver restored profiles on a later frame without DNS, files or a VPN.
class _RestoringConnection extends ConnectionController {
  _RestoringConnection()
    : super(
        engine: const UnavailableTunnelEngine(),
        xrayEngine: const UnavailableTunnelEngine(),
      );

  List<ServerProfile> _restoredProfiles = [];
  bool _restoring = true;

  @override
  List<ServerProfile> get profiles => _restoredProfiles;
  @override
  ServerProfile? get selected => _restoredProfiles.firstOrNull;
  @override
  bool get busy => _restoring;

  Future<void> hydrate(Future<List<ServerProfile>> savedProfiles) async {
    _restoredProfiles = await savedProfiles;
    _restoring = false;
    notifyListeners();
  }

  void clearProfiles() {
    _restoredProfiles = [];
    notifyListeners();
  }
}

void main() {
  for (final size in [const Size(360, 740), const Size(420, 800)]) {
    for (final textScale in [1.0, 1.4]) {
      testWidgets(
        'Connect position stays fixed during restore at $size, text scale $textScale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final connection = _RestoringConnection();
          final pings = NodePingController(connection);
          final savedProfiles = Completer<List<ServerProfile>>();
          final restoring = connection.hydrate(savedProfiles.future);
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: Scaffold(
                body: ListenableBuilder(
                  listenable: connection,
                  builder: (_, _) =>
                      ConnectionPage(connection: connection, pings: pings),
                ),
              ),
            ),
          );
          final button = find.byType(ConnectionButton);
          final slot = find.byKey(
            const ValueKey('connection-server-selector-slot'),
          );
          final initialButton = tester.getRect(button);
          final initialSlot = tester.getSize(slot);
          expect(initialSlot.height, greaterThan(0));
          expect(find.byType(ServerSelector).hitTestable(), findsNothing);

          // A delayed subscription must not shift the initial/loading layout.
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.getRect(button), initialButton);
          savedProfiles.complete([
            HysteriaProfile(
              name: 'A long restored server name',
              server: '192.0.2.1',
              port: 443,
              password: 'unused-test-password',
              serverName: 'example.invalid',
            ),
          ]);
          await restoring;
          await tester.pumpAndSettle();
          expect(find.byType(ServerSelector).hitTestable(), findsOneWidget);
          expect(tester.getSize(slot), initialSlot);
          expect(tester.getRect(button), initialButton);
          expect(tester.takeException(), isNull);

          // Removing the last subscription must not move the button either.
          connection.clearProfiles();
          await tester.pumpAndSettle();
          expect(find.byType(ServerSelector).hitTestable(), findsNothing);
          expect(tester.getRect(button), initialButton);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
