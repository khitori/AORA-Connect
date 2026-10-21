// SPDX-License-Identifier: GPL-3.0-or-later
import '../core/ping_type.dart';
import '../core/tunnel_engine.dart';
import '../controllers/node_ping_controller.dart';
import '../routing/routing_policy.dart';
import 'app_localizations.dart';

extension LocalizedTunnelState on TunnelState {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    TunnelState.stopped => l10n.stateStopped,
    TunnelState.starting => l10n.stateStarting,
    TunnelState.running => l10n.stateRunning,
    TunnelState.stopping => l10n.stateStopping,
  };
}

extension LocalizedRoutingAction on RoutingAction {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    RoutingAction.vpn => l10n.throughTunnel,
    RoutingAction.direct => l10n.bypassingTunnel,
  };
}

extension LocalizedRoutingMatch on RoutingMatch {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    RoutingMatch.application => l10n.application,
    RoutingMatch.domain => l10n.domainSubdomains,
    RoutingMatch.exactDomain => l10n.exactDomain,
    RoutingMatch.ip => l10n.ipCidr,
  };
}

extension LocalizedPingType on PingType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    PingType.proxyGet => l10n.proxyGet,
    PingType.proxyHead => l10n.proxyHead,
    _ => label,
  };
}

extension LocalizedPingResult on NodePingResult {
  String localizedLabel(AppLocalizations l10n) {
    if (pending) return '…';
    if (latency != null) {
      return latency!.inMilliseconds == 0
          ? l10n.lessOneMs
          : l10n.milliseconds(latency!.inMilliseconds.toString());
    }
    if (error == 'Cancelled') return '—';
    if (error?.contains('UDP-only') == true) return l10n.unavailable;
    return error == 'Timeout' ? l10n.timeout : l10n.failed;
  }
}

extension LocalizedRoutingIssue on RoutingValidationIssue {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    RoutingValidationIssue.empty => l10n.routingValidationEmpty,
    RoutingValidationIssue.controlCharacters =>
      l10n.routingValidationControlCharacters,
    RoutingValidationIssue.application => l10n.routingValidationApplication,
    RoutingValidationIssue.domain => l10n.routingValidationDomain,
    RoutingValidationIssue.ip => l10n.routingValidationIp,
    RoutingValidationIssue.prefix => l10n.routingValidationPrefix,
  };
}
