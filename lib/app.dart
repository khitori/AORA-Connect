// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'components/morphing_menu.dart';
import 'controllers/connection_controller.dart';
import 'core/tunnel_engine.dart';
import 'pages/connection_page.dart';
import 'pages/settings_page.dart';
import 'theme/app_theme.dart';

enum _AppPage { connection, settings }

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.engine, this.configPath});
  final TunnelEngine? engine;
  final String? configPath;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AORA Connect',
    theme: AppTheme.light,
    home: _AppShell(engine: engine, configPath: configPath),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({this.engine, this.configPath});
  final TunnelEngine? engine;
  final String? configPath;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late final ConnectionController _connection;
  late final AppLifecycleListener _lifecycle;
  final _subscriptionUrl = TextEditingController();
  _AppPage _page = _AppPage.connection;

  @override
  void initState() {
    super.initState();
    _connection = ConnectionController(
      engine: widget.engine,
      configPath: widget.configPath,
    );
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _connection.shutdown();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _subscriptionUrl.dispose();
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MorphingMenuShell<_AppPage>(
    selected: _page,
    onSelected: (page) => setState(() => _page = page),
    entries: const [
      MorphingMenuEntry(
        _AppPage.connection,
        'Connection',
        Icons.power_settings_new,
      ),
      MorphingMenuEntry(_AppPage.settings, 'Settings', Icons.settings_outlined),
    ],
    child: Scaffold(
      appBar: AppBar(
        leading: _page == _AppPage.connection
            ? null
            : IconButton(
                tooltip: 'Back to connection',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _page = _AppPage.connection),
              ),
        title: Text(_page == _AppPage.connection ? 'AORA Connect' : 'Settings'),
        actionsPadding: const EdgeInsets.only(right: 12),
        actions: const [SizedBox(width: 44)],
      ),
      body: ListenableBuilder(
        listenable: _connection,
        builder: (context, _) => _page == _AppPage.settings
            ? SettingsPage(connection: _connection)
            : ConnectionPage(
                connection: _connection,
                subscriptionUrl: _subscriptionUrl,
              ),
      ),
    ),
  );
}
