// SPDX-License-Identifier: GPL-3.0-or-later
enum PingType { icmp, tcp, proxyGet, proxyHead }

extension PingTypeLabel on PingType {
  String get label => switch (this) {
    PingType.icmp => 'ICMP',
    PingType.tcp => 'TCP',
    PingType.proxyGet => 'Via Proxy GET',
    PingType.proxyHead => 'Via Proxy HEAD',
  };
  bool get viaProxy => this == PingType.proxyGet || this == PingType.proxyHead;
}
