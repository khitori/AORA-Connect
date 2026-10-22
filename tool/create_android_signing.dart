// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main(List<String> args) async {
  final directory = Directory(
    args.isEmpty ? '.release-keys/android' : args.single,
  ).absolute;
  final store = File('${directory.path}/release.jks');
  final properties = File('${directory.path}/signing.properties');
  if (await store.exists() || await properties.exists()) {
    throw StateError(
      'Signing files already exist. Restore/reuse them; do not generate replacements.',
    );
  }
  await directory.create(recursive: true);
  if (Platform.isWindows) {
    final user = Platform.environment['USERNAME'];
    if (user == null) throw StateError('Could not identify the current user.');
    final acl = await Process.run('icacls', [
      directory.path,
      '/inheritance:r',
      '/grant:r',
      '$user:(OI)(CI)F',
      '*S-1-5-18:(OI)(CI)F',
    ]);
    if (acl.exitCode != 0) {
      throw StateError('Could not restrict access to the signing folder.');
    }
  } else {
    final acl = await Process.run('chmod', ['700', directory.path]);
    if (acl.exitCode != 0) {
      throw StateError('Could not secure the signing folder.');
    }
  }
  final random = Random.secure();
  final password = base64UrlEncode(
    List.generate(36, (_) => random.nextInt(256)),
  );
  final java = Platform.environment['JAVA_HOME'];
  final keytool = java != null
      ? '$java/bin/keytool${Platform.isWindows ? '.exe' : ''}'
      : Platform.isWindows
      ? 'C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe'
      : 'keytool';
  final result = await Process.run(
    keytool,
    [
      '-genkeypair',
      '-noprompt',
      '-storetype',
      'PKCS12',
      '-keystore',
      store.path,
      '-alias',
      'aora-release',
      '-storepass:env',
      'AORA_KEYSTORE_PASSWORD',
      '-keypass:env',
      'AORA_KEYSTORE_PASSWORD',
      '-keyalg',
      'RSA',
      '-keysize',
      '4096',
      '-validity',
      '10000',
      '-dname',
      'CN=AORA Connect',
    ],
    environment: {'AORA_KEYSTORE_PASSWORD': password},
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Android signing key generation failed (exit ${result.exitCode}).',
    );
  }
  await properties.writeAsString(
    'storeFile=release.jks\nstorePassword=$password\nkeyAlias=aora-release\nkeyPassword=$password\n',
    flush: true,
  );
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', store.path, properties.path]);
  }
  stdout.writeln(
    'Created Android signing files in ${directory.path}. Back up this entire folder securely.',
  );
}
