// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/updates/android_updates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final algorithm = Ed25519();
  late SimpleKeyPair key;
  late String public;
  Map<String, dynamic> release() => {
    'appId': 'AORAConnect',
    'platform': 'android-arm64',
    'version': '1.0.5+2',
    'size': 100,
    'sha256': 'ab' * 32,
    'urls': ['https://example.com/AORAConnect.apk'],
    'notes': 'Changes',
  };
  Future<List<int>> sign(Map<String, dynamic> data) async {
    final payload = utf8.encode(jsonEncode(data));
    final signature = await algorithm.sign(payload, keyPair: key);
    return utf8.encode(
      jsonEncode({
        'signed': base64Encode(payload),
        'signature': base64Encode(signature.bytes),
      }),
    );
  }

  setUp(() async {
    key = await algorithm.newKeyPairFromSeed(List.filled(32, 13));
    public = (await key.extractPublicKey()).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  });

  test('Authentic Android metadata is accepted', () async {
    expect(
      await AndroidUpdates.verifyManifest(await sign(release()), public),
      release(),
    );
  });
  test(
    'Modified payload, another key, and invalid signature are rejected',
    () async {
      final encoded = await sign(release());
      final envelope = jsonDecode(utf8.decode(encoded)) as Map;
      envelope['signed'] = base64Encode(
        utf8.encode(jsonEncode(release()..['size'] = 999)),
      );
      await expectLater(
        AndroidUpdates.verifyManifest(
          utf8.encode(jsonEncode(envelope)),
          public,
        ),
        throwsFormatException,
      );
      await expectLater(
        AndroidUpdates.verifyManifest(encoded, '11' * 32),
        throwsFormatException,
      );
      envelope['signature'] = base64Encode([1, 2]);
      await expectLater(
        AndroidUpdates.verifyManifest(
          utf8.encode(jsonEncode(envelope)),
          public,
        ),
        throwsFormatException,
      );
    },
  );
  test('Signed but unsafe or wrong-platform metadata is rejected', () async {
    for (final change in <Map<String, dynamic>>[
      {'appId': 'Other'},
      {'platform': 'windows-x64'},
      {'size': 0},
      {'size': 536870913},
      {'version': '1.0.5'},
      {'version': '1.0.5+0'},
      {'version': '1.0.5+2100000001'},
      {'sha256': 'invalid'},
      {'urls': []},
      {
        'urls': ['http://example.com/app.apk'],
      },
      {
        'urls': ['https://user:password@example.com/app.apk'],
      },
      {'unknown': true},
    ]) {
      await expectLater(
        AndroidUpdates.verifyManifest(
          await sign(release()..addAll(change)),
          public,
        ),
        throwsFormatException,
        reason: '$change',
      );
    }
    await expectLater(
      AndroidUpdates.verifyManifest(List.filled(65537, 0), public),
      throwsFormatException,
    );
  });

  test(
    'Native update bridge forwards info, staged APK verification and install',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AndroidUpdates.channel, (call) async {
        calls.add(call);
        if (call.method == 'installApk') return null;
        return {'version': '1.0.5+1'};
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(AndroidUpdates.channel, null),
      );
      expect((await AndroidUpdates.verify('info', ''))['version'], '1.0.5+1');
      await AndroidUpdates.verify('verify-package', '/private/update.apk');
      await AndroidUpdates.install('/private/update.apk');
      expect(calls.map((call) => call.method), [
        'info',
        'verifyApk',
        'installApk',
      ]);
      expect((calls.last.arguments as Map)['path'], '/private/update.apk');
    },
  );
}
