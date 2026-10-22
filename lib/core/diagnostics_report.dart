// SPDX-License-Identifier: GPL-3.0-or-later
import '../controllers/connection_controller.dart';
import 'core_kind.dart';

String diagnosticsSignals(Iterable<String> messages) {
  final signals = <String>{};
  const patterns = <String, String>{
    'connection refused': 'Connection refused',
    'timed out|timeout': 'Timeout',
    'quic: transport closed': 'QUIC transport closed',
    'tls.*(?:fail|error)|(?:fail|error).*tls|certificate.*(?:invalid|expired|fail|error)|x509:':
        'TLS/certificate issue',
    'dns (?:lookup|resolution).*(?:fail|error|timeout)|failed host lookup|no such host':
        'DNS lookup failed',
    'permission.*(?:denied|not granted)': 'Permission denied',
    'protect.*fail|binding failed': 'Outbound socket protection/binding failed',
    r'configuration valid\b': 'Configuration valid',
    'configuration validation failed': 'Configuration validation failed',
    'connection verified|https.*succeeded': 'Connection verification succeeded',
    'connection verification failed|connection test failed':
        'Connection verification failed',
    'vpn startup failed': 'VPN startup failed',
    'physical network selection timed out':
        'Physical network selection timed out',
  };
  for (final line in messages) {
    for (final entry in patterns.entries) {
      if (RegExp(entry.key, caseSensitive: false).hasMatch(line)) {
        signals.add(entry.value);
      }
    }
  }
  return signals.isEmpty
      ? 'No recognized diagnostic signals recorded.'
      : signals.map((s) => '- $s').join('\n');
}

String buildDiagnosticsReport(
  ConnectionController connection, {
  required String version,
  required String platform,
  String network = 'Not available',
  String? coreError,
}) => [
  'AORA Connect diagnostics',
  'Version: $version',
  'Platform: $platform',
  'Core: ${connection.activeCore.displayName}',
  'Protocol: ${connection.selected?.protocol ?? 'Not selected'}',
  'State: ${connection.state.name}',
  'Mode: ${connection.mode.name}',
  'DNS: ${connection.dnsProvider.label}',
  'Routing: ${connection.routingPolicy.enabled ? 'enabled' : 'disabled'}',
  'Routing rules: ${connection.routingPolicy.rules.length}',
  'Physical network: $network',
  '',
  'Recorded signals (not raw logs):',
  diagnosticsSignals([
    ...connection.logs.takeLast(100),
    ?connection.error,
    ?coreError,
  ]),
  '',
  'Subscription links, server names, credentials and raw configuration/logs are excluded.',
].join('\n');

extension on List<String> {
  Iterable<String> takeLast(int count) =>
      skip(length > count ? length - count : 0);
}
