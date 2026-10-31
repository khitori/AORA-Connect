// SPDX-License-Identifier: GPL-3.0-or-later
import '../profiles/server_profile.dart';
import '../routing/routing_policy.dart';
import 'connection_mode.dart';
import 'core_kind.dart';
import 'dns_provider.dart';
import 'tunnel_engine.dart';

class ConnectionPlan {
  ConnectionPlan({
    required ServerProfile profile,
    required String serverAddress,
    required this.mode,
    required this.dnsProvider,
    required this.leakProtection,
    required this.routing,
  }) : core = profile.coreKind,
       outbound = profile.outbound(serverAddress: serverAddress);
  final CoreKind core;
  final ConnectionMode mode;
  final DnsProvider dnsProvider;
  final bool leakProtection;
  final RoutingPolicy routing;
  final Map<String, Object?> outbound;

  Map<String, Object?> toJson() => {
    'core': core.name,
    'mode': mode.name,
    'dns': dnsProvider.name,
    'leakProtection': leakProtection,
    'routing': routing.toJson(),
    'outbound': outbound,
  };
}

abstract interface class PlannedTunnelEngine implements TunnelEngine {
  Future<void> validatePlan(ConnectionPlan plan);
  Future<void> startPlan(ConnectionPlan plan);
}
