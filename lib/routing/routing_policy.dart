// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import '../core/core_kind.dart';
import '../core/dns_provider.dart';

enum RoutingAction {
  vpn('Through tunnel'),
  direct('Bypassing tunnel');

  const RoutingAction(this.label);
  final String label;
}

enum RoutingMatch {
  application('Application', 'chrome.exe or C:/Apps/app.exe'),
  domain('Domain + subdomains', 'example.com'),
  exactDomain('Exact domain', 'example.com'),
  ip('IP / CIDR', '192.168.0.0/16');

  const RoutingMatch(this.label, this.hint);
  final String label;
  final String hint;
}

enum RoutingValidationIssue {
  empty,
  controlCharacters,
  application,
  domain,
  ip,
  prefix;

  String get message => switch (this) {
    RoutingValidationIssue.empty => "Enter a value.",
    RoutingValidationIssue.controlCharacters =>
      "Control characters are not allowed.",
    RoutingValidationIssue.application =>
      "Enter an executable path or process name, without wildcards.",
    RoutingValidationIssue.domain =>
      "Enter a domain without a URL scheme, path, or wildcard.",
    RoutingValidationIssue.ip => "Enter an IP address or CIDR range.",
    RoutingValidationIssue.prefix => "The CIDR prefix is invalid.",
  };
}

class RoutingRule {
  const RoutingRule({
    required this.match,
    required this.target,
    this.enabled = true,
  });
  final RoutingMatch match;
  final String target;
  final bool enabled;

  String? get validationError => validationIssue?.message;

  RoutingValidationIssue? get validationIssue {
    if (target.trim().isEmpty) return RoutingValidationIssue.empty;
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(target)) {
      return RoutingValidationIssue.controlCharacters;
    }
    if (match == RoutingMatch.application &&
        (target.endsWith('/') ||
            target.endsWith('\\') ||
            target.contains('*') ||
            target.contains('?'))) {
      return RoutingValidationIssue.application;
    }
    if (match == RoutingMatch.domain || match == RoutingMatch.exactDomain) {
      if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.-]*$').hasMatch(target) ||
          target.contains('..') ||
          target.length > 253) {
        return RoutingValidationIssue.domain;
      }
    }
    if (match == RoutingMatch.ip) {
      final parts = target.split('/');
      final address = InternetAddress.tryParse(parts.first);
      if (address == null || parts.length > 2) {
        return RoutingValidationIssue.ip;
      }
      if (parts.length == 2) {
        final prefix = int.tryParse(parts.last);
        final maximum = address.type == InternetAddressType.IPv4 ? 32 : 128;
        if (prefix == null || prefix < 0 || prefix > maximum) {
          return RoutingValidationIssue.prefix;
        }
      }
    }
    return null;
  }

  RoutingRule withEnabled(bool value) =>
      RoutingRule(match: match, target: target, enabled: value);

  Map<String, Object?> toJson() => {
    'match': match.name,
    'target': target,
    'enabled': enabled,
  };

  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    try {
      final rule = RoutingRule(
        match: RoutingMatch.values.byName(json['match'] as String),
        target: (json['target'] as String).trim(),
        enabled: json['enabled'] != false,
      );
      if (rule.validationError != null) throw const FormatException();
      return rule;
    } catch (_) {
      throw const FormatException('Saved routing rule is invalid.');
    }
  }
}

class RoutingPolicy {
  const RoutingPolicy({
    this.enabled = true,
    this.direction = RoutingAction.direct,
    this.rules = const [],
  });
  final bool enabled;
  final RoutingAction direction;
  RoutingAction get defaultAction =>
      !rules.any((rule) => rule.enabled) || direction == RoutingAction.direct
      ? RoutingAction.vpn
      : RoutingAction.direct;
  final List<RoutingRule> rules;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'direction': direction.name,
    'rules': rules.map((rule) => rule.toJson()).toList(),
  };

  factory RoutingPolicy.fromJson(Map<String, dynamic> json) => RoutingPolicy(
    enabled: json['enabled'] != false,
    direction: (json['direction'] ?? json['defaultAction']) == 'direct'
        ? RoutingAction.direct
        : RoutingAction.vpn,
    rules: List.unmodifiable([
      for (final rule in json['rules'] as List? ?? const [])
        RoutingRule.fromJson(Map<String, dynamic>.from(rule as Map)),
    ]),
  );
}

Map<String, Object?> applyRouting(
  Map<String, Object?> config,
  CoreKind core,
  RoutingPolicy policy, {
  DnsProvider dnsProvider = DnsProvider.cloudflare,
  bool? android,
}) {
  final androidRules = android ?? Platform.isAndroid;
  if (!policy.enabled ||
      policy.rules.every((rule) => !rule.enabled) &&
          policy.defaultAction == RoutingAction.vpn) {
    return config;
  }
  if (androidRules) {
    for (final rule in policy.rules.where(
      (rule) => rule.enabled && rule.match == RoutingMatch.application,
    )) {
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$')
          .hasMatch(rule.target)) {
        throw const FormatException(
          'Use an Android package name, such as com.android.chrome.',
        );
      }
    }
  }
  final outbounds = List<Map<String, Object?>>.from(
    config['outbounds'] as List,
  );
  config['outbounds'] = outbounds;
  if (core == CoreKind.singBox) {
    outbounds.add({'type': 'direct', 'tag': 'direct'});
    final route = Map<String, Object?>.from(config['route'] as Map? ?? {});
    config['route'] = route;
    final rules = List<Map<String, Object?>>.from(
      route['rules'] as List? ?? [],
    );
    route['rules'] = rules;
    final dns = Map<String, Object?>.from(config['dns'] as Map? ?? {});
    config['dns'] = dns;
    final servers = List<Map<String, Object?>>.from(
      dns['servers'] as List? ?? [],
    );
    dns['servers'] = servers;
    for (final tag in ['direct', 'proxy']) {
      final dnsTag = tag == 'proxy' ? 'vpn-dns' : 'direct-dns';
      if (!servers.any((server) => server['tag'] == dnsTag)) {
        servers.add(
          dnsProvider.singBoxServer(
            tag: dnsTag,
            detour: tag == 'proxy' ? tag : null,
          ),
        );
      }
    }
    dns['final'] = policy.defaultAction == RoutingAction.direct
        ? 'direct-dns'
        : 'vpn-dns';
    final dnsRules = List<Map<String, Object?>>.from(
      dns['rules'] as List? ?? [],
    );
    dns['rules'] = dnsRules;
    for (final rule in policy.rules.where((rule) => rule.enabled)) {
      final field = switch (rule.match) {
        RoutingMatch.application =>
          androidRules
              ? 'package_name'
              : rule.target.contains('/') || rule.target.contains('\\')
              ? 'process_path'
              : 'process_name',
        RoutingMatch.domain => 'domain_suffix',
        RoutingMatch.exactDomain => 'domain',
        RoutingMatch.ip => 'ip_cidr',
      };
      final compiled = <String, Object?>{
        field: [
          if (rule.match == RoutingMatch.ip && !rule.target.contains('/'))
            '${rule.target}/${InternetAddress.tryParse(rule.target)!.type == InternetAddressType.IPv4 ? 32 : 128}'
          else if (rule.match == RoutingMatch.application &&
              field == 'process_path' &&
              Platform.isWindows)
            rule.target.replaceAll('/', '\\')
          else
            rule.target,
        ],
        'action': 'route',
        'outbound': policy.direction == RoutingAction.vpn ? 'proxy' : 'direct',
      };
      rules.add(compiled);
      if (rule.match != RoutingMatch.ip) {
        dnsRules.add({
          field: compiled[field],
          'action': 'route',
          'server': policy.direction == RoutingAction.vpn
              ? 'vpn-dns'
              : 'direct-dns',
        });
      }
    }
    route['final'] = policy.defaultAction == RoutingAction.direct
        ? 'direct'
        : 'proxy';
  } else {
    outbounds.add({'protocol': 'freedom', 'tag': 'direct'});
    for (final inbound in config['inbounds'] as List) {
      (inbound as Map)['sniffing'] = {
        'enabled': true,
        'destOverride': ['http', 'tls', 'quic'],
        'routeOnly': true,
      };
    }
    final routing = Map<String, Object?>.from(config['routing'] as Map? ?? {});
    config['routing'] = routing;
    final rules = List<Map<String, Object?>>.from(
      routing['rules'] as List? ?? [],
    );
    routing['rules'] = rules;
    String tag(RoutingAction action) =>
        action == RoutingAction.vpn ? 'proxy' : action.name;
    for (final rule in policy.rules.where((rule) => rule.enabled)) {
      final field = switch (rule.match) {
        RoutingMatch.application => 'process',
        RoutingMatch.domain || RoutingMatch.exactDomain => 'domain',
        RoutingMatch.ip => 'ip',
      };
      final target = switch (rule.match) {
        RoutingMatch.application =>
          rule.target.contains('/') || rule.target.contains('\\')
              ? rule.target.replaceAll('\\', '/')
              : rule.target.replaceFirst(
                  RegExp(r'\.exe$', caseSensitive: false),
                  '',
                ),
        RoutingMatch.domain => 'domain:${rule.target}',
        RoutingMatch.exactDomain => 'full:${rule.target}',
        RoutingMatch.ip => rule.target,
      };
      rules.add({
        'type': 'field',
        field: [target],
        'outboundTag': tag(policy.direction),
      });
    }
    rules.add({
      'type': 'field',
      'network': 'tcp,udp',
      'outboundTag': tag(policy.defaultAction),
    });
  }
  return config;
}
