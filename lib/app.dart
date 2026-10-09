// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'components/floating_bottom_navigation.dart';
import 'components/morphing_menu.dart';
import 'controllers/connection_controller.dart';
import 'controllers/statistics_controller.dart';
import 'controllers/node_ping_controller.dart';
import 'core/tunnel_engine.dart';
import 'pages/connection_page.dart';
import 'pages/settings_page.dart';
import 'pages/routing_page.dart';
import 'pages/subscriptions_page.dart';
import 'storage/app_settings_store.dart';
import 'theme/app_theme.dart';

enum _AppPage { connection, subscriptions, routing, settings }

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.engine, this.configPath, this.settingsStore});
  final TunnelEngine? engine;
  final String? configPath;
  final AppSettingsStore? settingsStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AORA Connect',
    theme: AppTheme.light,
    home: _AppShell(
      engine: engine,
      configPath: configPath,
      settingsStore: settingsStore,
    ),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({this.engine, this.configPath, this.settingsStore});
  final TunnelEngine? engine;
  final String? configPath;
  final AppSettingsStore? settingsStore;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late final ConnectionController _connection;
  late final StatisticsController _statistics;
  late final NodePingController _pings;
  late final AppLifecycleListener _lifecycle;
  final _subscriptionUrl = TextEditingController();
  _AppPage _page = _AppPage.connection;

  @override
  void initState() {
    super.initState();
    _connection = ConnectionController(
      engine: widget.engine,
      configPath: widget.configPath,
      settingsStore:
          widget.settingsStore ??
          (widget.engine == null ? FileAppSettingsStore() : null),
    );
    _statistics = StatisticsController(_connection);
    _pings = NodePingController(_connection);
    unawaited(_connection.restore());
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _pings.shutdown();
        await _connection.shutdown();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _subscriptionUrl.dispose();
    _statistics.dispose();
    _pings.dispose();
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MorphingMenuShell<_AppPage>(
    selected: _page,
    entries: const [
      MorphingMenuEntry(_AppPage.settings, 'Settings', Icons.settings_outlined),
    ],
    onSelected: (page) => setState(() => _page = page),
    child: Scaffold(
      appBar: AppBar(
        actions: const [SizedBox(width: 56)],
        title: Text(switch (_page) {
          _AppPage.connection => 'AORA Connect',
          _AppPage.subscriptions => 'Subscriptions',
          _AppPage.routing => 'Routing',
          _AppPage.settings => 'Settings',
        }),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _connection,
              builder: (context, _) => switch (_page) {
                _AppPage.connection => ConnectionPage(
                  connection: _connection,
                  pings: _pings,
                ),
                _AppPage.subscriptions => SubscriptionsPage(
                  connection: _connection,
                  subscriptionUrl: _subscriptionUrl,
                  pings: _pings,
                ),
                _AppPage.settings => SettingsPage(
                  connection: _connection,
                  statistics: _statistics,
                ),
                _AppPage.routing => RoutingPage(connection: _connection),
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingBottomNavigation<_AppPage>(
              selected: _page,
              onSelected: (page) => setState(() => _page = page),
              destinations: const [
                FloatingNavigationDestination(
                  _AppPage.connection,
                  'Connection',
                  Icons.power_settings_new_rounded,
                ),
                FloatingNavigationDestination(
                  _AppPage.subscriptions,
                  'Subscriptions',
                  Icons.link_rounded,
                ),
                FloatingNavigationDestination(
                  _AppPage.routing,
                  'Routing',
                  Icons.alt_route_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
