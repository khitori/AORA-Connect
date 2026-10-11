// SPDX-License-Identifier: GPL-3.0-or-later
enum DnsProvider {
  cloudflare('Cloudflare', '1.1.1.1', 'cloudflare-dns.com'),
  google('Google', '8.8.8.8', 'dns.google'),
  quad9('Quad9', '9.9.9.9', 'dns.quad9.net');

  const DnsProvider(this.label, this.address, this.tlsServerName);

  final String label;
  final String address;
  final String tlsServerName;

  // Dial the IP directly, so reaching the DoH resolver needs no DNS bootstrap.
  Map<String, Object?> singBoxServer({required String tag, String? detour}) => {
    'type': 'https',
    'tag': tag,
    'server': address,
    'path': '/dns-query',
    'tls': {'enabled': true, 'server_name': tlsServerName},
    'detour': ?detour,
  };
}
