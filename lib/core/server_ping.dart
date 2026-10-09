// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

class ServerPingException implements Exception {
  const ServerPingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ICMP round-trip time to the selected server's resolved address.
Future<Duration> pingServer(String address) async {
  final output = await runPingHelper(address);
  final milliseconds = int.tryParse(output);
  if (milliseconds == null || milliseconds < 0) {
    throw const ServerPingException('Invalid ping response.');
  }
  return Duration(milliseconds: milliseconds);
}

Future<String> runPingHelper(
  String address, {
  List<String> options = const [],
  String? helperPath,
}) async {
  if (!Platform.isWindows) {
    throw const ServerPingException(
      'Server ping is currently available on Windows.',
    );
  }
  if (InternetAddress.tryParse(address) == null) {
    throw const ServerPingException('Select a server before checking ping.');
  }
  final helper =
      helperPath ??
      '${File(Platform.resolvedExecutable).parent.path}/aoravpn_server_ping.exe';
  if (!await File(helper).exists()) {
    throw const ServerPingException(
      'Restart the rebuilt app to enable server ping.',
    );
  }
  final result = await Process.run(helper, [
    address,
    ...options,
  ]).timeout(const Duration(seconds: 5));
  if (result.exitCode == 2) {
    throw const ServerPingException(
      'No reply. The server may block this check.',
    );
  }
  if (result.exitCode == 3) {
    throw const ServerPingException(
      'No physical network route to this server.',
    );
  }
  if (result.exitCode != 0) {
    throw const ServerPingException('Could not check server ping.');
  }
  return result.stdout.toString().trim();
}
