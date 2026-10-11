// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'components/floating_bottom_navigation.dart';
import 'components/compact_outline_icon_button.dart';
import 'components/app_notification.dart';
import 'updates/update_controller.dart';
import 'controllers/connection_controller.dart';
import 'controllers/statistics_controller.dart';
import 'controllers/node_ping_controller.dart';
import 'core/tunnel_engine.dart';
import 'core/desktop_window.dart';
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
  final _window = DesktopWindow();
  UpdateController? _updates;
  String? _announcedUpdate;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<void>? _exitCleanup;
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
    if (widget.engine == null && _window.supported) {
      _updates = UpdateController()..addListener(_updateChanged);
      unawaited(_updates!.initialize());
    }
    unawaited(_connection.restore());
    _connection.addListener(_syncTray);
    unawaited(
      _window
          .initialize(
            onExit: () async {
              await _cleanupForExit();
              await _window.command('destroy');
            },
            onDisconnect: () async {
              if (_connection.canStop) {
                await _connection.stop();
                final error = _connection.error;
                if (error != null) throw StateError(error);
              }
            },
            onError: _showWindowError,
          )
          .then((_) => _syncTray()),
    );
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _cleanupForExit();
        return AppExitResponse.exit;
      },
    );
  }

  Future<void> _cleanupForExit() => _exitCleanup ??= (() async {
    await _pings.shutdown();
    await _connection.shutdown();
  })();

  void _updateChanged() {
    if (!mounted) return;
    final version = _updates?.release?.version;
    if (version != null &&
        version != _announcedUpdate &&
        _scaffoldKey.currentContext != null) {
      _announcedUpdate = version;
      AppNotification.show(
        _scaffoldKey.currentContext!,
        'Update ${version.split('+').first} is available in Settings → Updates.',
      );
    }
  }

  Future<void> _installUpdate() async {
    await _updates!.install(
      canInstall: () => _connection.canEdit && !_pings.busy,
      launch: (path) async {
        if (!_connection.beginMaintenance()) {
          throw StateError('Disconnect before installing an update.');
        }
        try {
          await _window.command('install-update:$path');
          await _cleanupForExit();
          await _window.command('destroy');
        } catch (_) {
          _connection.cancelMaintenance();
          rethrow;
        }
      },
    );
  }

  void _showWindowError(Object error) {
    final context = _scaffoldKey.currentContext;
    if (mounted && context != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _syncTray() {
    unawaited(
      _window
          .setCanDisconnect(_connection.canStop)
          .catchError(_showWindowError),
    );
  }

  Future<void> _windowAction(String command) async {
    try {
      await _window.command(command);
    } catch (error) {
      _showWindowError(error);
    }
  }

  Widget _settingsButton() => CompactOutlineIconButton(
    key: const ValueKey('open-settings'),
    tooltip: 'Settings',
    icon: Icons.settings_outlined,
    onPressed: () => setState(() => _page = _AppPage.settings),
  );

  @override
  void dispose() {
    _connection.removeListener(_syncTray);
    _updates?.removeListener(_updateChanged);
    _updates?.dispose();
    _window.dispose();
    _lifecycle.dispose();
    _subscriptionUrl.dispose();
    _statistics.dispose();
    _pings.dispose();
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    appBar: AppBar(
      actions: _window.supported
          ? [
              _settingsButton(),
              const SizedBox(width: 6),
              CompactOutlineIconButton(
                tooltip: 'Hide to tray',
                icon: Icons.minimize_rounded,
                onPressed: () => _windowAction('tray'),
              ),
              const SizedBox(width: 6),
              CompactOutlineIconButton(
                tooltip: 'Close app',
                icon: Icons.close_rounded,
                onPressed: () => _windowAction('close'),
              ),
              const SizedBox(width: 12),
            ]
          : [_settingsButton(), const SizedBox(width: 12)],
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _window.supported ? (_) => _windowAction('drag') : null,
        child: SizedBox(
          height: kToolbarHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'lib/assets/logo.png',
                    key: const ValueKey('app-logo'),
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    switch (_page) {
                      _AppPage.connection => 'AORA Connect',
                      _AppPage.subscriptions => 'Subscriptions',
                      _AppPage.routing => 'Routing',
                      _AppPage.settings => 'Settings',
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                updates: _updates,
                onInstallUpdate: _updates == null ? null : _installUpdate,
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
  );
}
