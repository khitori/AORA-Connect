// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:aoravpn/updates/update_cache.dart';
import 'package:aoravpn/updates/update_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root, runtime;
  late UpdateCache cache;
  Future<Directory> session(String name, [String? version]) async {
    final directory = await Directory('${runtime.path}/update-$name')
        .create(recursive: true);
    if (version != null) {
      await File('${directory.path}/AORAConnect.apk').writeAsString(version);
    }
    return directory;
  }

  Future<Map<String, dynamic>> inspect(String path) async {
    final version = await File(path).readAsString();
    releaseVersion(version);
    return {
      'version': version,
      'size': 1,
      'sha256': 'ab' * 32,
      'urls': <String>[],
      'notes': '',
    };
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aora-cleanup-test-');
    runtime = await Directory('${root.path}/runtime').create();
    cache = UpdateCache(
      runtime,
      packageName: 'AORAConnect.apk',
      inspect: inspect,
      newer: (a, b) => releaseVersion(a).last > releaseVersion(b).last,
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'all obsolete, incomplete, invalid and metadata-only sessions are removed',
    () async {
      final old = await session('old', '1.0.0+1');
      final equal = await session('equal', '1.1.1+2');
      final partial = await session('partial', 'incomplete');
      final metadata = await session('metadata');
      await File('${old.path}/aoravpn_update.exe').writeAsString('helper');
      await File('${metadata.path}/aora-update.json').writeAsString('{}');
      expect(await cache.sweep('1.1.1+2'), isNull);
      for (final directory in [old, equal, partial, metadata]) {
        expect(await directory.exists(), isFalse, reason: directory.path);
      }
    },
  );

  test(
    'keeps only the newest authenticated pending version across restarts',
    () async {
      final first = await session('first', '1.1.2+3');
      final newest = await session('newest', '1.2.0+4');
      final duplicate = await session('duplicate', '1.1.2+3');
      final pending = await cache.sweep('1.1.1+2');
      expect(pending?.release['version'], '1.2.0+4');
      expect(await newest.exists(), isTrue);
      expect(await first.exists(), isFalse);
      expect(await duplicate.exists(), isFalse);
      await cache.sweep('1.2.0+4');
      expect(await newest.exists(), isFalse);
    },
  );

  test(
    'in-flight work is skipped and cleaned after releasing its lease',
    () async {
      final active = await session('active', 'partial');
      final lease = (await UpdateCache.acquire(active))!;
      try {
        await cache.sweep('1.1.1+2');
        expect(await active.exists(), isTrue);
      } finally {
        await UpdateCache.release(active, lease);
      }
      await cache.sweep('1.1.1+2');
      expect(await active.exists(), isFalse);
    },
  );

  test(
    'protects every handed-off newer installer until its version is installed',
    () async {
      final installing = await session('installing', '1.1.2+3');
      final latest = await session('latest', '1.2.0+4');
      await File('${installing.path}/installing.json')
          .writeAsString(jsonEncode({'version': '1.1.2+3'}));
      await cache.sweep('1.1.1+2');
      expect(await installing.exists(), isTrue);
      expect(await latest.exists(), isTrue);
      await cache.sweep('1.1.2+3');
      expect(await installing.exists(), isFalse);
      expect(await latest.exists(), isTrue);
    },
  );

  test(
    'never touches settings, cores, original downloads or unknown contents',
    () async {
      final unknown = await session('unknown', '1.0.0+1');
      final nested = await session('nested', '1.0.0+1');
      await File('${unknown.path}/personal.txt').writeAsString('keep');
      await Directory('${nested.path}/subfolder').create();
      final originals = <File>[];
      for (final relative in [
        'settings/preferences.json',
        'cores/core.exe',
        'runtime/profile-test/config.json',
        'Downloads/AORAConnect.apk',
      ]) {
        final file = File('${root.path}/$relative');
        await file.parent.create(recursive: true);
        await file.writeAsString('keep');
        originals.add(file);
      }
      await cache.sweep('1.1.1+2');
      expect(await unknown.exists(), isTrue);
      expect(await nested.exists(), isTrue);
      for (final file in originals) {
        expect(await file.readAsString(), 'keep');
      }
    },
  );

  test('locked leftovers are retried after their handle is closed', () async {
    if (!Platform.isWindows) return;
    final directory = await session('helper', '1.1.1+2');
    final lock = File('${directory.path}/.installer.lock');
    await lock.writeAsString('lease');
    final handle = await lock.open(mode: FileMode.append);
    await handle.lock(FileLock.exclusive);
    await cache.sweep('1.1.1+2');
    await handle.close();
    await cache.sweep('1.1.1+2');
    expect(await directory.exists(), isFalse);
  });

  test('controller recovers pending package and cleans it after successful upgrade', () async {
    await session('old', '1.0.0+1');
    final ready = await session('ready', '1.2.0+4');
    UpdateController controller(String version) => UpdateController(
      platform: UpdatePlatform.android,
      runtimeDirectory: runtime,
      preferencesDirectory: Directory('${root.path}/settings'),
      sessionCreator: () => runtime.createTemp('update-'),
      verifier: (command, path) async =>
          command == 'info' ? {'version': version} : inspect(path),
    );
    final before = controller('1.1.1+2');
    await before.initialize(checkAutomatically: false);
    expect(before.release?.version, '1.2.0+4');
    expect(before.package?.parent.uri, ready.uri);
    before.dispose();
    expect(await ready.exists(), isTrue);
    final after = controller('1.2.0+4');
    await after.initialize(checkAutomatically: false);
    expect(after.package, isNull);
    expect(await ready.exists(), isFalse);
    after.dispose();
  });

  test(
    'invalid imported copy is removed without deleting its original',
    () async {
      final source = await File('${root.path}/original.apk')
          .writeAsString('invalid');
      final controller = UpdateController(
        platform: UpdatePlatform.android,
        runtimeDirectory: runtime,
        preferencesDirectory: Directory('${root.path}/settings'),
        sessionCreator: () => runtime.createTemp('update-'),
        verifier: (command, path) async =>
            command == 'info' ? {'version': '1.1.1+2'} : inspect(path),
      );
      await controller.initialize(checkAutomatically: false);
      await controller.importFile(source.path);
      expect(controller.error, isNotNull);
      expect(await runtime.list().toList(), isEmpty);
      expect(await source.readAsString(), 'invalid');
      controller.dispose();
    },
  );

  test(
    'Windows imports stage only the package; the elevated helper copies itself',
    () async {
      final source = await File('${root.path}/original.exe')
          .writeAsString('1.2.0+4');
      final controller = UpdateController(
        platform: UpdatePlatform.windows,
        runtimeDirectory: runtime,
        helperPath: '${root.path}/missing-helper.exe',
        preferencesDirectory: Directory('${root.path}/settings'),
        sessionCreator: () => runtime.createTemp('update-'),
        verifier: (command, path) async =>
            command == 'info' ? {'version': '1.1.1+2'} : inspect(path),
      );
      await controller.initialize(checkAutomatically: false);
      await controller.importFile(source.path);
      expect(controller.error, isNull);
      expect(controller.package, isNotNull);
      final staged = [
        for (final entry in await controller.package!.parent.list().toList())
          entry.uri.pathSegments.last,
      ];
      expect(staged, isNot(contains('aoravpn_update.exe')));
      expect(staged, contains('AORAConnect-Setup.exe'));
      expect(await source.exists(), isTrue);
      controller.dispose();
    },
  );

  test(
    'a rejected concurrent install cannot remove another installer handoff',
    () async {
      final ready = await session('ready', '1.2.0+4');
      final marker = await File('${ready.path}/installing.json')
          .writeAsString(jsonEncode({'version': '1.2.0+4'}));
      final controller = UpdateController(
        platform: UpdatePlatform.android,
        runtimeDirectory: runtime,
        preferencesDirectory: Directory('${root.path}/settings'),
        verifier: (command, path) async =>
            command == 'info' ? {'version': '1.1.1+2'} : inspect(path),
      );
      await controller.initialize(checkAutomatically: false);
      final lease = (await UpdateCache.acquire(ready))!;
      try {
        await controller.install(
          canInstall: () => true,
          launch: (_) async => fail('Must not launch'),
        );
        expect(controller.error, contains('in use'));
        expect(await marker.exists(), isTrue);
      } finally {
        await UpdateCache.release(ready, lease);
        controller.dispose();
      }
    },
  );
}
