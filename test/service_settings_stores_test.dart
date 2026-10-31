// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/l10n/locale_controller.dart';
import 'package:aoravpn/storage/app_settings_store.dart';
import 'package:aoravpn/storage/service_settings_document.dart';
import 'package:aoravpn/storage/update_preferences_store.dart';
import 'package:aoravpn/storage/windows_settings_stores.dart';
import 'package:aoravpn/updates/update_controller.dart';

class MemoryService {
  final data = <String, Map<String, dynamic>>{};
  final revisions = <String, int>{};
  final commands = <Map<String, Object?>>[];
  bool fail = false;
  String revision(String name) => data.containsKey(name)
      ? (revisions[name] ?? 1).toRadixString(16).padLeft(64, '0')
      : 'missing';
  Future<Map<String, dynamic>> request(Map<String, Object?> value) async {
    commands.add(value);
    if (fail) throw StateError('Service unavailable');
    final name = value['document'] as String;
    if (value['command'] == 'settings.write') {
      if (value['revision'] != revision(name)) {
        return {'protocol': 1, 'ok': false, 'error': 'settings_conflict'};
      }
      data[name] =
          jsonDecode(jsonEncode(value['value'])) as Map<String, dynamic>;
      revisions[name] = (revisions[name] ?? 0) + 1;
      return {'protocol': 1, 'ok': true, 'revision': revision(name)};
    }
    return {
      'protocol': 1,
      'ok': true,
      'value': data[name],
      'revision': revision(name),
    };
  }

  ServiceSettingsDocument document(String name) =>
      ServiceSettingsDocument(name, request: request);
  WindowsAppSettingsStore app() => WindowsAppSettingsStore(
    document: document('app'),
    legacyReader: () async => null,
  );
}

class DelayedPreferences implements UpdatePreferencesStore {
  UpdatePreferencesData saved = const UpdatePreferencesData();
  final writing = Completer<void>();
  final release = Completer<void>();
  int writes = 0;
  @override
  Future<UpdatePreferencesData> read() async => saved;
  @override
  Future<void> write(UpdatePreferencesData value) async {
    if (writes++ == 0) {
      writing.complete();
      await release.future;
    }
    saved = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows settings require a successful typed read and do not fall back on failure', () async {
    final backend = MemoryService();
    final store = backend.app();
    await expectLater(store.write(const AppSettingsData()), throwsStateError);
    expect(backend.commands, isEmpty);
    backend.fail = true;
    await expectLater(store.read(), throwsStateError);
    await expectLater(store.write(const AppSettingsData()), throwsStateError);
    expect(
      backend.commands.every((value) => value['command'] == 'settings.read'),
      isTrue,
    );
    backend.fail = false;
    backend.data['app'] = {'version': 999};
    await expectLater(store.read(), throwsFormatException);
    await expectLater(store.write(const AppSettingsData()), throwsStateError);
    expect(backend.data['app']!['version'], 999);
  });

  test('Stale settings saves cannot overwrite another session', () async {
    final backend = MemoryService();
    final first = backend.app();
    final second = backend.app();
    await first.read();
    await second.read();
    await first.write(
      const AppSettingsData(
        core: CoreKind.xray,
        mode: ConnectionMode.proxy,
        statisticsEnabled: true,
      ),
    );
    await expectLater(second.write(const AppSettingsData()), throwsStateError);
    await expectLater(second.write(const AppSettingsData()), throwsStateError);
    final latest = await second.read();
    expect(latest.core, CoreKind.xray);
    expect(latest.mode, ConnectionMode.proxy);
    expect(latest.statisticsEnabled, isTrue);
    expect(
      backend.commands.any((request) => request.containsKey('path')),
      isFalse,
    );
  });

  test('Language is remembered through its service store, including system default', () async {
    final backend = MemoryService();
    final store = WindowsLanguageStore(document: backend.document('language'));
    final locale = LocaleController(store: store);
    await locale.initialize();
    await locale.select('he');
    final restored = LocaleController(
      store: WindowsLanguageStore(document: backend.document('language')),
    );
    await restored.initialize();
    expect(restored.language, 'he');
    await restored.select(null);
    expect(backend.data['language']!['language'], isNull);
    locale.dispose();
    restored.dispose();
  });

  test('Language startup failure is recoverable and cannot reset the stored choice', () async {
    final backend = MemoryService()..fail = true;
    backend.data['language'] = {'language': 'ru'};
    final locale = LocaleController(
      store: WindowsLanguageStore(document: backend.document('language')),
    );
    await locale.initialize();
    expect(locale.restoreFailed, isTrue);
    await expectLater(locale.select('en'), throwsStateError);
    expect(backend.data['language']!['language'], 'ru');
    backend.fail = false;
    await locale.reload();
    expect(locale.restoreFailed, isFalse);
    expect(locale.language, 'ru');
    locale.dispose();
  });

  test('Legacy import copies only into a missing document and retains newer saved settings', () async {
    final backend = MemoryService();
    var reads = 0;
    final store = WindowsAppSettingsStore(
      document: backend.document('app'),
      legacyReader: () async {
        reads++;
        return const AppSettingsData(core: CoreKind.xray);
      },
    );
    expect((await store.read()).core, CoreKind.xray);
    expect((await store.read()).core, CoreKind.xray);
    expect(reads, 1);
    final pending = Completer<AppSettingsData?>();
    backend.data.remove('app');
    final migrating = WindowsAppSettingsStore(
      document: backend.document('app'),
      legacyReader: () => pending.future,
    ).read();
    await Future<void>.delayed(Duration.zero);
    final other = backend.app();
    await other.read();
    await other.write(const AppSettingsData(statisticsEnabled: true));
    pending.complete(const AppSettingsData(core: CoreKind.xray));
    await expectLater(migrating, throwsStateError);
    expect((await other.read()).statisticsEnabled, isTrue);
  });

  test('Update preference stores preserve choices and reject corrupt data before saving', () async {
    final backend = MemoryService();
    final store = WindowsUpdatePreferencesStore(
      document: backend.document('updates'),
    );
    await store.read();
    await store.write(
      const UpdatePreferencesData(
        automaticChecks: false,
        sources: ['https://mirror.example/updates'],
      ),
    );
    final restored = await WindowsUpdatePreferencesStore(
      document: backend.document('updates'),
    ).read();
    expect(restored.automaticChecks, isFalse);
    expect(restored.sources, ['https://mirror.example/updates']);
    backend.data['updates'] = {
      'sources': ['file:///private'],
    };
    final corrupt = WindowsUpdatePreferencesStore(
      document: backend.document('updates'),
    );
    await expectLater(corrupt.read(), throwsFormatException);
    await expectLater(
      corrupt.write(const UpdatePreferencesData()),
      throwsStateError,
    );
    expect(backend.data['updates']!['sources'], ['file:///private']);
  });

  test('Concurrent update choices are applied in order without resetting each other', () async {
    final store = DelayedPreferences();
    final controller = UpdateController(preferencesStore: store);
    final first = controller.setPreferences(automatic: false);
    await store.writing.future;
    final second = controller.setPreferences(
      sources: ['https://mirror.example/updates'],
    );
    store.release.complete();
    await Future.wait([first, second]);
    expect(store.saved.automaticChecks, isFalse);
    expect(store.saved.sources, ['https://mirror.example/updates']);
    controller.dispose();
  });
}
