// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

class AndroidUpdates {
  static const channel = MethodChannel('aora/updates');
  static Future<Map<String, dynamic>> verify(
    String command,
    String path,
  ) async {
    if (command == 'verify-manifest') {
      final file = File(path);
      if (await file.length() > 65536) {
        throw const FormatException('Update metadata exceeds its size limit.');
      }
      final key = (await rootBundle.loadString('release/update-public-key.txt'))
          .trim();
      return verifyManifest(await file.readAsBytes(), key);
    }
    final value = await channel.invokeMapMethod<String, dynamic>(
      command == 'info'
          ? 'info'
          : command == 'inspect-package'
          ? 'inspectApk'
          : 'verifyApk',
      {'path': path},
    );
    if (value == null) {
      throw StateError('Android update verification returned no result.');
    }
    return Map<String, dynamic>.from(value);
  }

  static Future<void> install(String path) =>
      channel.invokeMethod<void>('installApk', {'path': path});

  static Future<void> cleanup() => channel.invokeMethod<void>('cleanupUpdates');

  static Future<Map<String, dynamic>> verifyManifest(
    List<int> bytes,
    String trustedKey,
  ) async {
    if (bytes.length > 65536) {
      throw const FormatException('Update metadata exceeds its size limit.');
    }
    final envelope = jsonDecode(utf8.decode(bytes));
    if (envelope is! Map ||
        envelope.length != 2 ||
        !envelope.containsKey('signed') ||
        !envelope.containsKey('signature')) {
      throw const FormatException('Invalid signed update metadata.');
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(trustedKey)) {
      throw StateError('Invalid trusted update key.');
    }
    final key = [
      for (var i = 0; i < 64; i += 2)
        int.parse(trustedKey.substring(i, i + 2), radix: 16),
    ];
    final payload = base64Decode(envelope['signed'] as String);
    final signature = base64Decode(envelope['signature'] as String);
    if (signature.length != 64 ||
        !await Ed25519().verify(
          payload,
          signature: Signature(
            signature,
            publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
          ),
        )) {
      throw const FormatException('Update signature did not verify.');
    }
    final release = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(payload)) as Map,
    );
    const fields = {
      'appId',
      'platform',
      'version',
      'size',
      'sha256',
      'urls',
      'notes',
    };
    if (release.length != fields.length ||
        !fields.containsAll(release.keys) ||
        release['appId'] != 'AORAConnect' ||
        release['platform'] != 'android-arm64') {
      throw const FormatException(
        'Update is for a different application or platform.',
      );
    }
    final version = release['version'];
    final size = release['size'];
    final urls = release['urls'];
    if (version is! String ||
        !RegExp(r'^\d+\.\d+\.\d+\+[1-9]\d*$').hasMatch(version) ||
        int.parse(version.split('+').last) > 2100000000 ||
        size is! int ||
        size <= 0 ||
        size > 512 * 1024 * 1024 ||
        release['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(release['sha256'] as String) ||
        release['notes'] is! String ||
        urls is! List ||
        urls.isEmpty ||
        urls.length > 16) {
      throw const FormatException('Invalid Android release metadata.');
    }
    for (final url in urls) {
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException(
          'Update downloads require HTTPS URLs without credentials.',
        );
      }
    }
    return release;
  }
}
