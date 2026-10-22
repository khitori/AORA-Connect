// SPDX-License-Identifier: GPL-3.0-or-later
// ignore_for_file: avoid_print
import 'dart:io';

Future<void> main() async {
  final directory = Directory('build/android-update-test');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 18081);
  print('AORA_UPDATE_GATEWAY_READY');
  const allowed = {
    'newer.apk',
    'other-app.apk',
    'wrong-key.apk',
    'aora-update-android.json',
  };
  await for (final request in server) {
    final name = request.uri.pathSegments.lastOrNull;
    final file = name == null ? null : File('${directory.path}/$name');
    if (!allowed.contains(name) || file == null || !await file.exists()) {
      request.response.statusCode = 404;
      await request.response.close();
      continue;
    }
    await request.response.addStream(file.openRead());
    await request.response.close();
  }
}
