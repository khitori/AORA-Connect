// SPDX-License-Identifier: GPL-3.0-or-later
// Isolated aora.aoranet.aoravpn.updatetest package only. No real credentials.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aoravpn/storage/app_paths.dart';
import 'package:aoravpn/updates/android_updates.dart';
import 'package:aoravpn/updates/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = ValueNotifier('Verifying Android updates');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (_, text, _) => Text(text),
          ),
        ),
      ),
    ),
  );
  try {
    final root = await AppPaths.root();
    if (!root.path.contains('.updatetest/')) {
      throw StateError('Only run in the isolated update-test package.');
    }
    final installed = await AndroidUpdates.verify('info', '');
    final marker = File('${root.path}/update-test-settings.json');
    if ((installed['version'] as String).endsWith('+2')) {
      if (!await marker.exists() ||
          (jsonDecode(await marker.readAsString()) as Map)['retained'] !=
              true) {
        throw StateError('Settings were not preserved by the upgrade.');
      }
      status.value = 'Upgrade preserved test settings';
      print('AORA_ANDROID_UPDATE_RETENTION_OK');
      return;
    }
    await marker.writeAsString(
      jsonEncode({'retained': true, 'subscription': 'synthetic-test-only'}),
    );
    final directory = await AppPaths.createSession('update-test-');
    final client = HttpClient();
    Future<File> fetch(String name) async {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:18081/$name'),
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        throw StateError('Fixture missing: $name');
      }
      final file = File('${directory.path}/$name');
      await response.pipe(file.openWrite());
      return file;
    }

    try {
      final apk = await fetch('newer.apk');
      final candidate = await AndroidUpdates.verify('verify-package', apk.path);
      if (!(candidate['version'] as String).endsWith('+2')) {
        throw StateError('Wrong test APK version.');
      }
      print('AORA_ANDROID_APK_VALID_OK');
      final manifest = await fetch('aora-update-android.json');
      final signed = await AndroidUpdates.verify(
        'verify-manifest',
        manifest.path,
      );
      if (signed['sha256'] != candidate['sha256']) {
        throw StateError('Signed metadata does not match APK.');
      }
      print('AORA_ANDROID_MANIFEST_DEVICE_OK');
      final tampered = await apk.copy('${directory.path}/tampered.apk');
      final handle = await tampered.open(mode: FileMode.append);
      await handle.setPosition(512);
      await handle.writeByte(255);
      await handle.close();
      try {
        await AndroidUpdates.verify('verify-package', tampered.path);
        throw StateError('Modified APK was accepted.');
      } on PlatformException {
        print('AORA_ANDROID_APK_TAMPER_REJECTED');
      }
      final other = await fetch('other-app.apk');
      try {
        await AndroidUpdates.verify('verify-package', other.path);
        throw StateError('Different application APK was accepted.');
      } on PlatformException {
        print('AORA_ANDROID_APK_OTHER_APP_REJECTED');
      }
      final wrongKey = await fetch('wrong-key.apk');
      try {
        await AndroidUpdates.verify('verify-package', wrongKey.path);
        throw StateError('Untrusted signing key was accepted.');
      } on PlatformException {
        print('AORA_ANDROID_APK_WRONG_KEY_REJECTED');
      }
      final updates = UpdateController();
      await updates.initialize(checkAutomatically: false);
      await updates.setPreferences(
        automatic: false,
        sources: ['https://mirror.example/aora-update-android.json'],
      );
      await updates.importFile(apk.path);
      if (updates.package == null) {
        throw StateError('Offline APK import failed: ${updates.error}');
      }
      updates.dispose();
      status.value = 'APK checks passed; ready for isolated upgrade test';
      print('AORA_ANDROID_UPDATE_VERIFY_OK');
    } finally {
      client.close(force: true);
    }
  } catch (error) {
    status.value = 'Update verification failed: $error';
    print('AORA_ANDROID_UPDATE_SMOKE_FAILED: $error');
  }
}
