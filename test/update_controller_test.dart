// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/updates/update_controller.dart';

void main() {
  test(
    'Update versions include build numbers and reject non-release formats',
    () {
      expect(newerRelease('1.0.0+2', '1.0.0+1'), isTrue);
      expect(newerRelease('1.0.0+1', '1.0.0+2'), isFalse);
      expect(newerRelease('1.1.0+1', '1.0.0+99'), isTrue);
      expect(newerRelease('1.0.0+1', '1.0.0+1'), isFalse);
      expect(() => releaseVersion('1.0.0-beta'), throwsFormatException);
      for (final uri in [
        'http://example.com/update.json',
        'https://user:password@example.com/update.json',
        'file:///update.json',
      ]) {
        expect(() => updateUrl(uri), throwsFormatException);
      }
    },
  );

  test('Offline updates require verification, a newer build and an idle connection', () async {
    final root = await Directory.systemTemp.createTemp(
      'aora-update-controller-',
    );
    final helper = await File('${root.path}/helper.exe')
        .writeAsString('test helper');
    final source = await File('${root.path}/download.exe')
        .writeAsString('test fixture');
    var verified = true;
    var nextVersion = '1.0.0+2';
    var verifications = 0;
    final controller = UpdateController(
      helperPath: helper.path,
      preferencesDirectory: Directory('${root.path}/settings'),
      sessionCreator: () => root.createTemp('update-'),
      verifier: (command, path) async {
        if (command == 'info') return {'version': '1.0.0+1'};
        verifications++;
        if (!verified) throw StateError('Invalid signature');
        return {
          'version': nextVersion,
          'size': 10,
          'sha256': 'ab' * 32,
          'urls': ['https://example.com/setup.exe'],
          'notes': 'Fixture',
        };
      },
    );
    await controller.initialize(checkAutomatically: false);
    await controller.importFile(source.path);
    expect(controller.package, isNotNull);
    expect(controller.release!.version, '1.0.0+2');
    var launched = false;
    await controller.install(
      canInstall: () => false,
      launch: (_) async {
        launched = true;
      },
    );
    expect(launched, isFalse);
    expect(controller.error, contains('Disconnect'));
    verified = false;
    await controller.install(
      canInstall: () => true,
      launch: (_) async {
        launched = true;
      },
    );
    expect(launched, isFalse);
    expect(controller.error, contains('Invalid signature'));
    verified = true;
    nextVersion = '1.0.0+1';
    await controller.importFile(source.path);
    expect(controller.error, contains('newer'));
    nextVersion = '1.0.0+2';
    await controller.importFile(source.path);
    await controller.install(
      canInstall: () => true,
      launch: (_) async {
        launched = true;
      },
    );
    expect(launched, isTrue);
    expect(verifications, greaterThanOrEqualTo(4));
    await controller.setPreferences(
      automatic: false,
      sources: ['https://mirror.example/aora-update.json'],
    );
    final restored = UpdateController(
      helperPath: helper.path,
      preferencesDirectory: Directory('${root.path}/settings'),
      verifier: (command, path) async => {'version': '1.0.0+1'},
    );
    await restored.initialize(checkAutomatically: false);
    expect(restored.automaticChecks, isFalse);
    expect(restored.additionalSources, [
      'https://mirror.example/aora-update.json',
    ]);
    restored.dispose();
    controller.dispose();
    await root.delete(recursive: true);
  });
}
