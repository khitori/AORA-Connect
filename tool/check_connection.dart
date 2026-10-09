// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:aoravpn/core/connection_probe.dart';
import 'package:aoravpn/core/connection_mode.dart';
import 'package:aoravpn/core/windows_core_engine.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/storage/app_paths.dart';

// Read the secret URL from stdin instead of storing it in the repository.
Future<void> main(List<String> arguments) async {
  final mode = arguments.contains('--tun')
      ? ConnectionMode.tun
      : ConnectionMode.proxy;
  final url = stdin.readLineSync();
  if (url == null || url.trim().isEmpty) {
    stderr.writeln('A subscription URL is required on stdin.');
    exitCode = 1;
    return;
  }
  final directory = await AppPaths.createSession('connection-check-');
  final engine = WindowsSingBoxEngine(
    executablePath: File('cores/sing-box-1.14.2-windows-amd64/sing-box.exe')
        .absolute
        .path,
    hostPath: File('build/windows/x64/runner/Debug/aoravpn_core_host.exe')
        .absolute
        .path,
  );
  try {
    final profiles = await loadSubscription(url);
    final profile = profiles.first;
    final reserved = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reserved.port;
    await reserved.close();
    final config = File('${directory.path}/config.json');
    final addresses = await InternetAddress.lookup(profile.server);
    final address = addresses.firstWhere(
      (value) => value.type == InternetAddressType.IPv4,
      orElse: () => addresses.first,
    );
    await config.writeAsString(
      jsonEncode(
        profile.config(
          listenPort: port,
          mode: mode,
          serverAddress: address.address,
        ),
      ),
    );
    stdout.writeln('Subscription loaded: ${profiles.length} profile(s).');
    if (arguments.contains('--validate-only')) {
      await engine.validate(config.path);
      stdout.writeln('Configuration accepted by sing-box.');
      return;
    }
    await engine.start(config.path);
    stdout.writeln('Core started; probing HTTPS through ${profile.protocol}.');
    final elapsed = await probeConnection(
      port: mode == ConnectionMode.tun ? null : port,
    );
    stdout.writeln('HTTPS probe succeeded (${elapsed.inMilliseconds} ms).');
  } catch (error) {
    // Errors from network and URI parsing are sanitized by the helpers.
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await engine.dispose();
    await directory.delete(recursive: true);
    stdout.writeln('Core stopped and temporary credentials removed.');
  }
}
