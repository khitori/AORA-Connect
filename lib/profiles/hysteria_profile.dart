// SPDX-License-Identifier: GPL-3.0-or-later
import 'server_profile.dart';

class HysteriaProfile extends ServerProfile {
  HysteriaProfile({
    required super.name,
    required super.server,
    required super.port,
    required this.password,
    required this.serverName,
    super.insecure = false,
    this.alpn,
    this.obfs,
    this.obfsPassword,
  });

  final String password;
  final String serverName;
  final List<String>? alpn;
  final String? obfs;
  final String? obfsPassword;

  @override
  String get protocol => 'hysteria2';

  factory HysteriaProfile.parse(String value) {
    try {
      final uri = Uri.parse(value.trim());
      if (!['hysteria2', 'hy2'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const FormatException();
      }
      final parameters = uri.queryParameters;
      if (parameters.keys.any(
        (key) =>
            !{'sni', 'insecure', 'alpn', 'obfs', 'obfs-password'}.contains(key),
      )) {
        throw const FormatException('Unsupported Hysteria2 URI parameter.');
      }
      final obfs = parameters['obfs'];
      if (obfs != null && !['salamander', 'gecko'].contains(obfs)) {
        throw const FormatException('Unsupported obfuscation type.');
      }
      if (obfs != null && (parameters['obfs-password'] ?? '').isEmpty) {
        throw const FormatException('Obfuscation password is missing.');
      }
      final insecure = parameters['insecure'];
      if (insecure != null && !['0', '1'].contains(insecure)) {
        throw const FormatException('Invalid insecure TLS flag.');
      }
      final alpn = parameters['alpn']?.split(',');
      if (alpn != null && alpn.any((value) => value.isEmpty)) {
        throw const FormatException('Invalid Hysteria2 ALPN.');
      }
      final port = uri.hasPort ? uri.port : 443;
      if (port < 1 || port > 65535) throw const FormatException();
      return HysteriaProfile(
        name: uri.fragment.isEmpty
            ? uri.host
            : Uri.decodeComponent(uri.fragment),
        server: uri.host,
        port: port,
        password: Uri.decodeComponent(uri.userInfo),
        serverName: parameters['sni'] ?? uri.host,
        insecure: insecure == '1',
        alpn: alpn,
        obfs: obfs,
        obfsPassword: parameters['obfs-password'],
      );
    } on FormatException catch (error) {
      throw FormatException(
        error.message.isEmpty
            ? 'Invalid Hysteria2 link; this importer supports single-port links.'
            : error.message.startsWith('Unsupported') ||
                  error.message.startsWith('Obfuscation') ||
                  error.message.startsWith('Invalid insecure')
            ? error.message
            : 'Invalid Hysteria2 link; this importer supports single-port links.',
      );
    }
  }

  @override
  Map<String, Object?> outbound({String? serverAddress}) => {
    'type': protocol,
    'tag': 'proxy',
    'server': serverAddress ?? server,
    'server_port': port,
    'password': password,
    'tls': {
      'enabled': true,
      'server_name': serverName,
      'insecure': insecure,
      if (alpn != null) 'alpn': alpn,
    },
    if (obfs != null) 'obfs': {'type': obfs!, 'password': obfsPassword!},
  };
}
