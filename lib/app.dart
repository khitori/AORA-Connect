// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/app_notification.dart';
import 'components/compact_outline_icon_button.dart';
import 'components/floating_bottom_navigation.dart';
import 'controllers/connection_controller.dart';
import 'controllers/node_ping_controller.dart';
import 'controllers/statistics_controller.dart';
import 'core/desktop_window.dart';
import 'core/tunnel_engine.dart';
import 'l10n/l10n.dart';
import 'l10n/locale_controller.dart';
import 'pages/connection_page.dart';
import 'pages/routing_page.dart';
import 'pages/settings_page.dart';
import 'pages/subscriptions_page.dart';
import 'storage/app_settings_store.dart';
import 'theme/app_theme.dart';
import 'updates/android_updates.dart';
import 'updates/update_controller.dart';

enum _AppPage { connection, subscriptions, routing, settings }

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.engine,
    this.configPath,
    this.settingsStore,
    this.localeController,
  });
  final TunnelEngine? engine;
  final String? configPath;
  final AppSettingsStore? settingsStore;
  final LocaleController? localeController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final LocaleController _locale =
      widget.localeController ??
      LocaleController(
        store: widget.engine == null ? FileLanguageStore() : null,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_locale.initialize());
  }

  @override
  void dispose() {
    if (widget.localeController == null) _locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocaleScope(
    controller: _locale,
    child: ListenableBuilder(
      listenable: _locale,
      builder: (context, _) => MaterialApp(
        title: 'AORA Connect',
        theme: AppTheme.light,
        locale: _locale.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: _AppShell(
          engine: widget.engine,
          configPath: widget.configPath,
          settingsStore: widget.settingsStore,
        ),
      ),
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
  AppLocalizations? _strings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _strings = context.l10n;
    _syncTray();
    if (Platform.isAndroid) {
      final language = LocaleScope.maybeOf(context)?.language;
      unawaited(
        const MethodChannel('aora/localization')
            .invokeMethod<void>('setLanguage', language)
            .catchError(_showWindowError),
      );
    }
  }

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
    if (widget.engine == null && (_window.supported || Platform.isAndroid)) {
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
        context.l10n.updateAvailableNotification(
          isolateTechnicalValue(context.l10n, version.split('+').first),
        ),
      );
    }
  }

  Future<void> _installUpdate() async {
    await _updates!.install(
      canInstall: () => _connection.canEdit && !_pings.busy,
      launch: (path) async {
        if (!_connection.beginMaintenance()) {
          throw StateError(context.l10n.disconnectInstall);
        }
        try {
          if (Platform.isAndroid) {
            try {
              await AndroidUpdates.install(path);
            } finally {
              _connection.cancelMaintenance();
            }
            return;
          }
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
    final strings = _strings;
    if (strings != null) {
      unawaited(_window.setLabels(strings).catchError(_showWindowError));
    }
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
    tooltip: context.l10n.settings,
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
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _window.supported || _page == _AppPage.connection,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _page = _AppPage.connection);
    },
    child: _buildScaffold(context),
  );

  Widget _buildScaffold(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    appBar: AppBar(
      titleSpacing: 24,
      actionsPadding: EdgeInsets.zero,
      actions: _window.supported
          ? [
              _settingsButton(),
              const SizedBox(width: 6),
              CompactOutlineIconButton(
                tooltip: context.l10n.hideToTray,
                icon: Icons.minimize_rounded,
                onPressed: () => _windowAction('tray'),
              ),
              const SizedBox(width: 6),
              CompactOutlineIconButton(
                tooltip: context.l10n.closeApp,
                icon: Icons.close_rounded,
                onPressed: () => _windowAction('close'),
              ),
              const SizedBox(width: 24),
            ]
          : [_settingsButton(), const SizedBox(width: 24)],
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _window.supported ? (_) => _windowAction('drag') : null,
        child: SizedBox(
          height: kToolbarHeight,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
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
                      _AppPage.subscriptions => context.l10n.subscriptions,
                      _AppPage.routing => context.l10n.routing,
                      _AppPage.settings => context.l10n.settings,
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
            destinations: [
              FloatingNavigationDestination(
                _AppPage.subscriptions,
                context.l10n.subscriptions,
                Icons.link_rounded,
                id: 'subscriptions',
              ),
              FloatingNavigationDestination(
                _AppPage.connection,
                context.l10n.connection,
                Icons.power_settings_new_rounded,
                id: 'connection',
              ),
              FloatingNavigationDestination(
                _AppPage.routing,
                context.l10n.routing,
                Icons.alt_route_rounded,
                id: 'routing',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
