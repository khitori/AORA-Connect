// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/app.dart';
import 'package:aoravpn/core/desktop_window.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/components/updates_panel.dart';
import 'package:aoravpn/components/subscription_timing.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/updates/update_controller.dart';
import 'package:aoravpn/l10n/app_localizations.dart';
import 'package:aoravpn/l10n/app_localizations_ru.dart';
import 'package:aoravpn/l10n/locale_controller.dart';
import 'package:aoravpn/pages/settings_page.dart';

class _Engine implements TunnelEngine {
  @override
  TunnelState state = TunnelState.stopped;
  final changes = StreamController<TunnelState>.broadcast();
  int stops = 0;
  @override
  Stream<TunnelState> get states => changes.stream;
  @override
  Stream<String> get logs => const Stream.empty();
  @override
  Future<void> validate(String path) async {}
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await changes.close();
  }
}

class _MemoryStore implements LanguageStore {
  String? language;
  bool fail = false;
  Completer<String?>? pendingRead;
  @override
  Future<String?> read() async =>
      pendingRead == null ? language : pendingRead!.future;
  @override
  Future<void> write(String? value) async {
    if (fail) throw const FileSystemException('Fixture write failure');
    language = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Language persists separately from subscriptions and supports resetting to system', () async {
    final directory = Directory.systemTemp.createTempSync('aora-language-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final settings = File('${directory.path}/app-state.json')
      ..writeAsStringSync('{"fixture":"keep"}');
    final store = FileLanguageStore(directory: directory);
    final controller = LocaleController(store: store);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.select('ru');
    final restored = LocaleController(store: store);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.language, 'ru');
    await restored.select(null);
    expect(await store.read(), isNull);
    expect(settings.readAsStringSync(), '{"fixture":"keep"}');
  });

  test('Unsupported or corrupt saved choices fall back safely', () async {
    final directory = Directory.systemTemp.createTempSync(
      'aora-language-invalid-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = FileLanguageStore(directory: directory);
    for (final content in [
      'not-json',
      '{"language":42}',
      '{"language":"xx"}',
    ]) {
      File('${directory.path}/language.json').writeAsStringSync(content);
      final controller = LocaleController(store: store);
      await controller.initialize();
      expect(controller.locale, isNull);
      controller.dispose();
    }
  });

  test('A late restore cannot overwrite a user selection; failed saves keep the current choice', () async {
    final store = _MemoryStore()..pendingRead = Completer<String?>();
    final controller = LocaleController(store: store);
    addTearDown(controller.dispose);
    final restoring = controller.initialize();
    await controller.select('ru');
    store.pendingRead!.complete('en');
    await restoring;
    expect(controller.language, 'ru');
    store.fail = true;
    await expectLater(
      controller.select('en'),
      throwsA(isA<FileSystemException>()),
    );
    expect(controller.language, 'ru');
    store.fail = false;
    await controller.select('en');
    expect(controller.language, 'en');
  });

  test('Russian plural forms and translation catalogs are complete', () {
    final ru = AppLocalizationsRu();
    expect(ru.daysLeft(1), 'Остался 1 день');
    expect(ru.daysLeft(2), 'Осталось 2 дня');
    expect(ru.daysLeft(5), 'Осталось 5 дней');
    expect(ru.daysLeft(21), 'Остался 21 день');
    expect(ru.serverCount(1), '1 сервер');
    expect(ru.serverCount(12), '12 серверов');
    expect(ru.serverCount(22), '22 сервера');
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    for (final locale in AppLocalizations.supportedLocales) {
      final translated = jsonDecode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map;
      expect(
        translated.keys.where((key) => !key.startsWith('@')).toSet(),
        en.keys.where((key) => !key.startsWith('@')).toSet(),
      );
      expect(
        translated.values.whereType<String>().where(
          (text) => text.trim().isEmpty,
        ),
        isEmpty,
      );
    }
  });

  for (final width in [360.0, 420.0]) {
    testWidgets(
      'Live Russian switching preserves the active connection at $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final commands = <String?>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<String>(DesktopWindow.channel, (
              message,
            ) async {
              commands.add(message);
              return 'ok';
            });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<String>(
                DesktopWindow.channel,
                null,
              ),
        );
        final locale = LocaleController(language: 'en');
        addTearDown(locale.dispose);
        final engine = _Engine();
        await tester.pumpWidget(
          MyApp(engine: engine, localeController: locale),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-settings')));
        await tester.pumpAndSettle();
        final connection = tester
            .widget<SettingsPage>(find.byType(SettingsPage))
            .connection;
        engine.state = TunnelState.running;
        engine.changes.add(TunnelState.running);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('language-selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Русский'));
        await tester.pumpAndSettle();
        expect(find.text('Язык'), findsOneWidget);
        expect(find.text('Настройки'), findsOneWidget);
        expect(
          tester.widget<SettingsPage>(find.byType(SettingsPage)).connection,
          same(connection),
        );
        expect(connection.state, TunnelState.running);
        expect(engine.stops, 0);
        expect(tester.takeException(), isNull);
        if (DesktopWindow().supported) {
          expect(
            commands.whereType<String>().any(
              (value) =>
                  value.startsWith('localize:') && value.contains('Отключить'),
            ),
            isTrue,
          );
        }
        // Check the content and translated labels of the principal settings cards.
        await tester.tap(find.text('Ядро'));
        await tester.pumpAndSettle();
        expect(find.text('Сетевое ядро'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const ValueKey('bottom-nav-subscriptions')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Добавить подписку'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('bottom-nav-routing')));
        await tester.pumpAndSettle();
        expect(find.text('Маршрутизация'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('open-settings')));
        await tester.pumpAndSettle();
        await locale.select('en');
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'Russian update controls and subscription dates fit a compact window',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final connection = ConnectionController(
        engine: _Engine(),
        xrayEngine: _Engine(),
      );
      final updates = UpdateController();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await connection.shutdown();
        connection.dispose();
        updates.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                UpdatesPanel(
                  updates: updates,
                  connection: connection,
                  onInstall: () async {},
                ),
                SubscriptionTiming(updatedAt: DateTime(2026, 10, 21, 14, 5)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновления'));
      await tester.pumpAndSettle();
      expect(find.text('Обновить из файла'), findsOneWidget);
      expect(find.text('21.10.2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'System Russian resolves regionally and an unsupported system locale falls back to English',
    (tester) async {
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('ru', 'RU'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Text(AppLocalizations.of(context).settings),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Настройки'), findsOneWidget);
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('it', 'IT'),
      ];
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    },
  );

  test(
    'All added languages persist, expose native names, and format counts',
    () async {
      expect(AppLocalizations.supportedLocales.first, const Locale('en'));
      for (final entry in const {
        'de': ('Deutsch', 'Noch 1 Tag', 'Noch 2 Tage'),
        'fr': ('Français', 'Encore 1 jour', 'Encore 2 jours'),
        'es': ('Español', 'Queda 1 día', 'Quedan 2 días'),
        'zh': ('中文（简体）', '剩余 1 天', '剩余 2 天'),
        'he': ('עברית', 'נותר יום אחד', 'נותרו יומיים'),
      }.entries) {
        final store = _MemoryStore();
        final controller = LocaleController(store: store);
        await controller.initialize();
        await controller.select(entry.key);
        final restored = LocaleController(store: store);
        await restored.initialize();
        expect(restored.language, entry.key);
        expect(LocaleController.nativeName(entry.key), entry.value.$1);
        final strings = await AppLocalizations.delegate.load(restored.locale!);
        expect(strings.daysLeft(1), entry.value.$2);
        expect(strings.daysLeft(2), entry.value.$3);
        controller.dispose();
        restored.dispose();
      }
    },
  );

  test('Each supported locale has a complete Android notification catalog', () {
    Set<String> names(String path) =>
        RegExp(r'<string name="([^"]+)">')
            .allMatches(File(path).readAsStringSync())
            .map((match) => match[1]!)
            .toSet();
    const root = 'android/app/src/main/res';
    final expected = names('$root/values/aora_language.xml');
    final registry = File(
      'android/app/src/main/kotlin/aora/aoranet/aoravpn/AppLanguage.kt',
    ).readAsStringSync();
    for (final locale in AppLocalizations.supportedLocales) {
      final path = locale.languageCode == 'en'
          ? 'values'
          : 'values-${locale.languageCode}';
      expect(names('$root/$path/aora_language.xml'), expected);
      expect(registry, contains('"${locale.languageCode}"'));
    }
  });

  for (final code in ['de', 'fr', 'es', 'zh', 'ar', 'fa', 'he']) {
    for (final width in [360.0, 420.0]) {
      testWidgets(
        '$code settings, navigation, and update controls fit at $width px',
        (tester) async {
          tester.view.physicalSize = Size(width, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<String>(
                DesktopWindow.channel,
                (_) async => 'ok',
              );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockDecodedMessageHandler<String>(
                  DesktopWindow.channel,
                  null,
                ),
          );
          final controller = LocaleController(language: 'en');
          addTearDown(controller.dispose);
          final strings = await AppLocalizations.delegate.load(Locale(code));
          final engine = _Engine();
          await tester.pumpWidget(
            MyApp(engine: engine, localeController: controller),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('open-settings')));
          await tester.pumpAndSettle();
          final connection = tester
              .widget<SettingsPage>(find.byType(SettingsPage))
              .connection;
          await tester.tap(find.text('Language'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('language-selector')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(LocaleController.nativeName(code)));
          await tester.pumpAndSettle();
          expect(find.text(strings.interfaceLanguage), findsOneWidget);
          expect(find.text(strings.settings), findsOneWidget);
          final direction = Directionality.of(
            tester.element(find.byType(SettingsPage)),
          );
          expect(
            direction,
            ['ar', 'fa', 'he'].contains(code)
                ? TextDirection.rtl
                : TextDirection.ltr,
          );
          final connectionX = tester
              .getCenter(find.byKey(const ValueKey('bottom-nav-connection')))
              .dx;
          final routingX = tester
              .getCenter(find.byKey(const ValueKey('bottom-nav-routing')))
              .dx;
          expect(connectionX > routingX, ['ar', 'fa', 'he'].contains(code));
          expect(
            tester.widget<SettingsPage>(find.byType(SettingsPage)).connection,
            same(connection),
          );
          await tester.tap(find.text(strings.core));
          await tester.pumpAndSettle();
          expect(find.text(strings.networkingCore), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.byKey(const ValueKey('bottom-nav-subscriptions')),
          );
          await tester.pumpAndSettle();
          expect(find.text(strings.addSubscription), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('bottom-nav-routing')));
          await tester.pumpAndSettle();
          expect(find.text(strings.routing), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();

          final updateConnection = ConnectionController(
            engine: _Engine(),
            xrayEngine: _Engine(),
          );
          final updates = UpdateController();
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(code),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    UpdatesPanel(
                      updates: updates,
                      connection: updateConnection,
                      onInstall: () async {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings.updates));
          await tester.pumpAndSettle();
          expect(find.text(strings.importUpdate), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(updateConnection.shutdown);
          updateConnection.dispose();
          updates.dispose();
        },
      );
    }
  }
}
