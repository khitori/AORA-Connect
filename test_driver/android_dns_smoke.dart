// SPDX-License-Identifier: GPL-3.0-or-later
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:aoravpn/components/installed_application_picker.dart';
import 'package:aoravpn/core/android_tunnel_engine.dart';
import 'package:aoravpn/core/connection_probe.dart';
import 'package:aoravpn/core/dns_provider.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/storage/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('DNS verification'))),
    ),
  );
  final engine = AndroidTunnelEngine();
  final subscription = engine.logs.listen((line) {
    if (RegExp(r'\b(ERROR|FATAL)\b').hasMatch(line) ||
        line.contains('log stream')) {
      print('AORA_DNS_CORE: $line');
    }
  });
  Directory? temporary;
  var ownsSession = false;
  try {
    await engine.ready;
    if (engine.state != TunnelState.stopped) {
      throw StateError('Disconnect before testing.');
    }
    final apps = await InstalledApplication.load();
    if (apps.isEmpty) throw StateError('Installed application list is empty.');
    print('AORA_INSTALLED_APPS_OK count=${apps.length}');
    final root = await AppPaths.root();
    final candidates = <File>[];
    await for (final entry in Directory('${root.path}/runtime').list()) {
      if (entry is! Directory ||
          !entry.path.split('/').last.startsWith('profile-')) {
        continue;
      }
      final config = File('${entry.path}/config.json');
      if (await config.exists()) candidates.add(config);
    }
    candidates.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    if (candidates.isEmpty) {
      throw StateError('Select a sing-box server in the normal app first.');
    }
    final original = jsonDecode(
      await candidates.first.readAsString(),
    ) as Map<String, dynamic>;
    if (!(original['inbounds'] as List).any((item) => item['type'] == 'tun')) {
      throw StateError('The most recent profile is not sing-box TUN.');
    }
    temporary = await AppPaths.createSession('dns-smoke-');
    final file = File('${temporary.path}/config.json');
    for (final provider in [
      DnsProvider.quad9,
      DnsProvider.cloudflare,
      DnsProvider.google,
    ]) {
      final config = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      final dns = config['dns'] as Map<String, dynamic>;
      dns['servers'] = [
        for (final server in dns['servers'] as List)
          if (server['type'] == 'https')
            provider.singBoxServer(
              tag: server['tag'] as String,
              detour: server['detour'] as String?,
            )
          else
            server,
      ];
      await file.writeAsString(jsonEncode(config));
      await engine.validate(file.path);
      ownsSession = true;
      await engine.start(file.path);
      try {
        await probeConnection(port: null);
        print('AORA_DNS_PROVIDER_OK ${provider.name}');
      } catch (error) {
        print('AORA_DNS_PROVIDER_FAILED ${provider.name}: $error');
      } finally {
        await engine.stop();
        ownsSession = false;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    print('AORA_DNS_SMOKE_DONE');
  } catch (error) {
    print('AORA_DNS_SMOKE_FAILED: $error');
  } finally {
    if (ownsSession) await engine.stop();
    await subscription.cancel();
    await engine.dispose();
    await temporary?.delete(recursive: true);
  }
}
