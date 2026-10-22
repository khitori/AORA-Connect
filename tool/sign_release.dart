// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'init <private-key-path> | sign <private-key-path> <installer> <version+build> <download-url>',
    );
  }
  final keyFile = File(args[1]);
  final algorithm = Ed25519();
  if (args[0] == 'init') {
    if (keyFile.existsSync()) {
      throw StateError('Refusing to overwrite an existing signing key.');
    }
    final key = await algorithm.newKeyPair();
    final secret = await key.extractPrivateKeyBytes();
    final public = await key.extractPublicKey();
    await keyFile.parent.create(recursive: true);
    await keyFile.writeAsString(
      jsonEncode({
        'seed': base64Encode(secret),
        'publicKey': hex(public.bytes),
      }),
      flush: true,
    );
    await File('release/update-public-key.txt').parent.create(recursive: true);
    await File('release/update-public-key.txt')
        .writeAsString('${hex(public.bytes)}\n');
    stdout.writeln(
      'Release key created. Private key: ${keyFile.absolute.path}. Back it up securely; do not publish it.',
    );
    return;
  }
  final android = args[0] == 'sign-android';
  if ((!android && args[0] != 'sign') || args.length != 5) {
    throw ArgumentError('Invalid signing arguments.');
  }
  final keyJson = jsonDecode(await keyFile.readAsString()) as Map;
  final key = await algorithm.newKeyPairFromSeed(
    base64Decode(keyJson['seed'] as String),
  );
  final public = await key.extractPublicKey();
  final trusted = (await File(
    'release/update-public-key.txt',
  ).readAsString()).trim();
  if (hex(public.bytes) != trusted) {
    throw StateError(
      'Signing key does not match the key bundled in this build.',
    );
  }
  final installer = File(args[2]);
  final size = await installer.length();
  final hash = await crypto.sha256.bind(installer.openRead()).first;
  final signed = utf8.encode(
    jsonEncode({
      'appId': 'AORAConnect',
      'platform': android ? 'android-arm64' : 'windows-x64',
      'version': args[3],
      'size': size,
      'sha256': hex(hash.bytes),
      'urls': [args[4]],
      'notes': Platform.environment['AORA_RELEASE_NOTES'] ?? '',
    }),
  );
  final signature = await algorithm.sign(signed, keyPair: key);
  final envelope = utf8.encode(
    jsonEncode({
      'signed': base64Encode(signed),
      'signature': base64Encode(signature.bytes),
    }),
  );
  if (envelope.length > 65536) {
    throw StateError('Release metadata exceeds 64 KiB.');
  }
  if (android) {
    await File('${installer.parent.path}/aora-update-android.json')
        .writeAsBytes(envelope, flush: true);
    stdout.writeln(
      'Generated signed aora-update-android.json; APK bytes unchanged.',
    );
    return;
  }
  final footer = ByteData(24);
  for (var i = 0; i < 8; i++) {
    footer.setUint8(i, ascii.encode('AORAUPD1')[i]);
  }
  footer.setUint64(8, size, Endian.little);
  footer.setUint64(16, envelope.length, Endian.little);
  final stream = installer.openWrite(mode: FileMode.append);
  stream.add(envelope);
  stream.add(footer.buffer.asUint8List());
  await stream.close();
  await File('${installer.parent.path}/aora-update.json')
      .writeAsBytes(envelope, flush: true);
  stdout.writeln('Signed installer and aora-update.json generated.');
}
